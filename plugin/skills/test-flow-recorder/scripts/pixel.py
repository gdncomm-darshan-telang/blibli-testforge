#!/usr/bin/env python3
"""Samples a screenshot at point coordinates, so a colour expectation is an assertion
rather than 'look at the picture'. Screenshots come back at the simulator's scale, so
points are converted using the image width against a 428pt-wide screen.

Three forms, each `label=<coords>`:

    label=x,y            one point -> its hex colour
    label=x,y,w,h        a rect -> its darkest ("ink") and lightest ("paper") pixel, because
                         text and icons are antialiased and a single sample lands on a blend
    label=x,y,w:span     a horizontal run of `w` points at `y` -> each colour run, as
                         `start-end (width)`. This is how a progress fill is measured: the
                         fill/track boundary is a colour change at a known x, so "capped at
                         95%" becomes a width in points instead of an eyeball judgement.
"""
import sys
from PIL import Image

SCREEN_POINTS = 428.0

def main():
    path = sys.argv[1]
    image = Image.open(path).convert("RGB")
    scale = image.width / SCREEN_POINTS
    print(f"{path}  {image.width}x{image.height}  scale={scale:.2f}")
    for pair in sys.argv[2:]:
        label, _, coords = pair.partition("=")
        span = coords.endswith(":span")
        numbers = [float(v) for v in coords.removesuffix(":span").split(",")]
        if span and len(numbers) != 3:
            raise SystemExit(f"{label}: a span takes x,y,width")
        if len(numbers) == 2:
            x, y = numbers
            pixel = image.getpixel((int(x * scale), int(y * scale)))
            print(f"  {label:<22} ({x:.0f},{y:.0f}) -> #{pixel[0]:02X}{pixel[1]:02X}{pixel[2]:02X}")
            continue
        # A rect: text and icons are antialiased, so the extremes carry the real ink and paper
        # colours where a single sample would land on a blend.
        if len(numbers) == 3:
            x, y, width = numbers
            runs = []
            for offset in range(int(width)):
                pixel = image.getpixel((int((x + offset) * scale), int(y * scale)))
                if runs and runs[-1][0] == pixel:
                    runs[-1][2] = x + offset
                else:
                    runs.append([pixel, x + offset, x + offset])
            print(f"  {label:<22} span({x:.0f},{y:.0f},{width:.0f})")
            for pixel, start, end in runs:
                # Never drop a one-point run: a 1% progress fill is 2pt wide, and filtering short
                # runs as noise hides precisely the measurement being taken.
                print(f"      #{pixel[0]:02X}{pixel[1]:02X}{pixel[2]:02X}  x {start:.0f}-{end:.0f}  ({end - start + 1:.0f}pt)")
            continue
        x, y, width, height = numbers
        crop = image.crop((int(x * scale), int(y * scale), int((x + width) * scale), int((y + height) * scale)))
        pixels = list(crop.getdata())
        darkest = min(pixels, key=sum)
        lightest = max(pixels, key=sum)
        print(f"  {label:<22} rect({x:.0f},{y:.0f},{width:.0f}x{height:.0f}) -> ink #{darkest[0]:02X}{darkest[1]:02X}{darkest[2]:02X}"
              f"  paper #{lightest[0]:02X}{lightest[1]:02X}{lightest[2]:02X}")

main()
