#!/usr/bin/env python3
"""Publishes an evidence page to Confluence: resolve the parent, upload the media, write the body.

Three things this exists to stop being remembered:

* **Where a page lands.** Every page this skill creates goes under the mobile team's own page unless
  the caller names somewhere else. A page filed somewhere ad hoc is a page nobody finds again.
* **Who can see it.** A new page is restricted to the person who ran it, because the default parent
  lives in a *shared* space — an unreviewed evidence page appearing team-wide reads as a finding the
  team has agreed with. Widening access is the author's decision and this script never makes it.
* **The order of operations.** Attachments go up before the body, because a reference to a file that
  is not on the page yet renders as a macro error rather than a blank. The page version is read
  immediately before the write, because uploading attachments bumps it.

Reads CONFLUENCE_URL, CONFLUENCE_USER and CONFLUENCE_TOKEN from the environment.
"""
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

# Team Mobile (Blibli app) — the default home for anything this skill publishes, iOS and Android
# alike. Overridden with --parent, never silently.
DEFAULT_PARENT_ID = "326278640"
DEFAULT_PARENT_NAME = "Team Mobile (Blibli app)"
PAGE_ID_IN_URL = re.compile(r"/pages/(\d+)")
TINY_LINK = re.compile(r"/x/([A-Za-z0-9_-]+)")


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


class Confluence:

    def __init__(self) -> None:
        self.base = (os.environ.get("CONFLUENCE_URL") or "").rstrip("/")
        user = os.environ.get("CONFLUENCE_USER")
        token = os.environ.get("CONFLUENCE_TOKEN")
        if not (self.base and user and token):
            fail("CONFLUENCE_URL, CONFLUENCE_USER and CONFLUENCE_TOKEN must all be set")
        self.auth = base64.b64encode(f"{user}:{token}".encode()).decode()

    def request(self, method: str, path: str, payload=None, *, raw=None, content_type=None):
        request = urllib.request.Request(f"{self.base}{path}", method=method)
        request.add_header("Authorization", f"Basic {self.auth}")
        body = None
        if payload is not None:
            body = json.dumps(payload).encode()
            request.add_header("Content-Type", "application/json")
        elif raw is not None:
            body = raw
            request.add_header("Content-Type", content_type or "application/octet-stream")
            request.add_header("X-Atlassian-Token", "no-check")
        try:
            with urllib.request.urlopen(request, body, timeout=300) as response:
                text = response.read().decode()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as error:
            detail = error.read().decode()[:400]
            fail(f"{method} {path} -> HTTP {error.code}: {detail}")

    def account_id(self) -> str:
        return self.request("GET", "/rest/api/user/current")["accountId"]


def resolve_parent(argument: str | None) -> str:
    """A pasted page URL, a bare id, or nothing at all."""
    if not argument:
        return DEFAULT_PARENT_ID
    if argument.isdigit():
        return argument
    found = PAGE_ID_IN_URL.search(argument)
    if found:
        return found.group(1)
    if TINY_LINK.search(argument):
        fail("that is a tiny link (/x/…) and its page id cannot be derived from the URL alone — "
             "open it and pass the full /pages/<id>/… link, or the bare id")
    fail(f"could not find a page id in {argument!r}")
    return ""


def child_by_title(api: Confluence, parent_id: str, title: str) -> dict | None:
    start = 0
    while True:
        page = api.request("GET", f"/rest/api/content/{parent_id}/child/page?limit=100&start={start}")
        for child in page.get("results", []):
            if child["title"] == title:
                return child
        if len(page.get("results", [])) < 100:
            return None
        start += 100


def multipart(file_path: Path) -> tuple[bytes, str]:
    boundary = f"----qa{uuid.uuid4().hex}"
    mime = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    head = (f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{file_path.name}"\r\n'
            f"Content-Type: {mime}\r\n\r\n").encode()
    tail = (f"\r\n--{boundary}\r\n"
            'Content-Disposition: form-data; name="minorEdit"\r\n\r\ntrue\r\n'
            f"--{boundary}--\r\n").encode()
    return head + file_path.read_bytes() + tail, f"multipart/form-data; boundary={boundary}"


def sync_attachments(api: Confluence, page_id: str, media: Path) -> None:
    """Uploads what is missing or has changed, by name *and* size.

    Size matters: a multi-MB upload can answer with a success-shaped body and still not land, so the
    page's own attachment list is the only thing worth believing.
    """
    on_page: dict[str, int] = {}
    start = 0
    while True:
        listing = api.request(
            "GET", f"/rest/api/content/{page_id}/child/attachment?limit=100&start={start}&expand=extensions")
        for row in listing.get("results", []):
            on_page[row["title"]] = row["extensions"].get("fileSize")
        if len(listing.get("results", [])) < 100:
            break
        start += 100

    # `attachments.txt` is build_evidence.py's own staging manifest — bookkeeping for whoever
    # uploads the media, not evidence of anything. It lives in the same directory, so it has to be
    # excluded by name or it lands on the page as a stray file readers have to wonder about.
    skipped = {"attachments.txt", ".DS_Store"}
    wanted = {p: p.stat().st_size for p in sorted(media.iterdir())
              if p.is_file() and p.name not in skipped}
    pending = [p for p, size in wanted.items() if on_page.get(p.name) != size]
    print(f"  attachments: {len(wanted)} local, {len(pending)} to upload")
    for path in pending:
        raw, content_type = multipart(path)
        api.request("PUT", f"/rest/api/content/{page_id}/child/attachment",
                    raw=raw, content_type=content_type)
        print(f"    + {path.name} ({path.stat().st_size // 1024} KB)")

    verify: dict[str, int] = {}
    start = 0
    while True:
        listing = api.request(
            "GET", f"/rest/api/content/{page_id}/child/attachment?limit=100&start={start}&expand=extensions")
        for row in listing.get("results", []):
            verify[row["title"]] = row["extensions"].get("fileSize")
        if len(listing.get("results", [])) < 100:
            break
        start += 100
    missing = [p.name for p, size in wanted.items() if verify.get(p.name) != size]
    if missing:
        fail("these attachments are absent or the wrong size after upload, so the body would render "
             f"macro errors: {', '.join(missing)}")
    print("  attachments verified by name and byte size")


def restrict_to_author(api: Confluence, page_id: str, account_id: str) -> None:
    api.request("PUT", f"/rest/api/content/{page_id}/restriction", payload=[
        {"operation": operation,
         "restrictions": {"user": [{"type": "known", "accountId": account_id}], "group": []}}
        for operation in ("read", "update")])


def describe_access(api: Confluence, page_id: str) -> str:
    current = api.request(
        "GET", f"/rest/api/content/{page_id}/restriction?expand=restrictions.user,restrictions.group")
    parts = []
    for row in current.get("results", []):
        users = row["restrictions"]["user"]["results"]
        groups = row["restrictions"]["group"]["results"]
        if users or groups:
            parts.append(f"{row['operation']}: {len(users)} user(s), {len(groups)} group(s)")
    return "; ".join(parts) or "unrestricted — inherits the space"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--title", required=True)
    parser.add_argument("--body-file", required=True, type=Path,
                        help="Confluence storage-format body. Generated, never typed inline.")
    parser.add_argument("--parent", help=f"page URL or id. Default: {DEFAULT_PARENT_NAME} "
                                         f"({DEFAULT_PARENT_ID})")
    parser.add_argument("--media-dir", type=Path,
                        help="uploaded before the body is written, never after")
    parser.add_argument("--version-message", default="test-flow-recorder run")
    arguments = parser.parse_args()

    if not arguments.body_file.exists():
        fail(f"body file not found: {arguments.body_file}")

    api = Confluence()
    parent_id = resolve_parent(arguments.parent)
    parent = api.request("GET", f"/rest/api/content/{parent_id}?expand=space")
    space_key = parent["space"]["key"]
    print(f"parent: {parent['title']} ({parent_id}) in space {space_key}"
          + ("" if arguments.parent else "  [default]"))

    existing = child_by_title(api, parent_id, arguments.title)
    body = {"storage": {"value": arguments.body_file.read_text(), "representation": "storage"}}

    if existing:
        page_id = existing["id"]
        print(f"page: updating {arguments.title} ({page_id})")
        if arguments.media_dir:
            sync_attachments(api, page_id, arguments.media_dir)
        # Read the version immediately before the write: uploading attachments bumps it, so a number
        # computed earlier is already stale and the write would be rejected.
        current = api.request("GET", f"/rest/api/content/{page_id}")
        api.request("PUT", f"/rest/api/content/{page_id}", payload={
            "id": page_id, "type": "page", "title": arguments.title,
            "space": {"key": space_key},
            "version": {"number": current["version"]["number"] + 1,
                        "message": arguments.version_message},
            "body": body})
        # Restrictions are deliberately left alone here. Whoever widened access to this page decided
        # to; silently narrowing it back on every re-publish would undo that without telling anyone.
        print(f"  access unchanged — {describe_access(api, page_id)}")
    else:
        print(f"page: creating {arguments.title}")
        created = api.request("POST", "/rest/api/content", payload={
            "type": "page", "title": arguments.title, "space": {"key": space_key},
            "ancestors": [{"id": parent_id}], "body": body})
        page_id = created["id"]
        restrict_to_author(api, page_id, api.account_id())
        print(f"  restricted to you — {describe_access(api, page_id)}")
        if arguments.media_dir:
            sync_attachments(api, page_id, arguments.media_dir)
            current = api.request("GET", f"/rest/api/content/{page_id}")
            api.request("PUT", f"/rest/api/content/{page_id}", payload={
                "id": page_id, "type": "page", "title": arguments.title,
                "space": {"key": space_key},
                "version": {"number": current["version"]["number"] + 1,
                            "message": "embed the uploaded evidence"},
                "body": body})

    rendered = api.request("GET", f"/rest/api/content/{page_id}?expand=body.view")
    view = rendered["body"]["view"]["value"]
    broken = view.count("Error rendering macro") + view.count("Cannot find attachment")
    print(f"  rendered {len(view)} bytes, {broken} macro/attachment error(s)")
    if broken:
        fail("the published page renders errors — fix the body or the attachments before sharing it")

    print(f"\n{api.base}/spaces/{space_key}/pages/{page_id}")
    if not existing:
        print("\nAccess is restricted to you. Review the page, then grant the people who need it —\n"
              "this script never widens access on your behalf, because the default parent sits in a\n"
              "shared space and an unreviewed evidence page appearing team-wide reads as a finding\n"
              "the team has already agreed with.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
