import { test } from "node:test";
import assert from "node:assert/strict";
import { parseDecodableFields } from "../lib/swift-decodable.js";

// Fixtures below are copied from the real
// BlibliMobile-iOS/BlibliMobile-iOS/CustomerExperience/Engagement/FlashsaleRevamp-2026/Shared/Networking/FSResponseModel.swift
// so the parser is tested against this codebase's actual decode-line style, not an idealised one.

const RANGE_ITEM = `
/// One item of \`GET /backend/content/sub-flashsale/range\`'s \`data\` array — a schedule plus its
/// products; schedules beyond the backend's \`subFlashsaleByRangeProductScheduleLimit\` decode with
/// an empty \`products\` array rather than nil.
struct FSSubFlashsaleRangeItemResponse: Codable {
    let start: Double?
    let end: Double?
    let id: String?
    let isTimeBased: Bool?
    @SafeURL var logo: URL?
    let subFlashsaleTitle: String?
    @SafeURL var subFlashsaleUrl: URL?
    let background: FSBackgroundResponse?
    let products: [HomeProduct]?

    enum CodingKeys: String, CodingKey {
        case start, end, id, logo, subFlashsaleTitle, subFlashsaleUrl, background, products
        case isTimeBased = "timeBased"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        start = try values.decodeIfPresent(Double.self, forKey: .start)
        end = try values.decodeIfPresent(Double.self, forKey: .end)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        isTimeBased = try values.decodeIfPresent(Bool.self, forKey: .isTimeBased)
        _logo = try values.decode(SafeURL.self, forKey: .logo)
        subFlashsaleTitle = try values.decodeIfPresent(String.self, forKey: .subFlashsaleTitle)
        _subFlashsaleUrl = try values.decode(SafeURL.self, forKey: .subFlashsaleUrl)
        background = try values.decodeIfPresent(FSBackgroundResponse.self, forKey: .background)
        products = try values.decodeIfPresent([HomeProduct].self, forKey: .products)
    }
}
`;

const SPECIAL_PLACEMENT = `
/// \`data\` payload of \`GET /backend/content-api/special-placement\`.
struct FSSpecialPlacementResponse: Codable {
    let id: String?
    let name: String?
    let type: String?
    let placementSchedule: Double?
    let products: [String: [FSSpecialPlacementProductResponse]]?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        type = try values.decodeIfPresent(String.self, forKey: .type)
        placementSchedule = try values.decodeIfPresent(Double.self, forKey: .placementSchedule)
        products = try values.decodeIfPresent([String: [FSSpecialPlacementProductResponse]].self, forKey: .products)
    }
}
`;

// FSQuotaStatus is real; FSQuotaResponse is a fixture wrapper built only to exercise a top-level
// enum field, since no real struct in FSResponseModel.swift has one at the top level.
const QUOTA = `
enum FSQuotaStatus: String, Codable {
    case available = "AVAILABLE"
    case limited = "LIMITED"
    case outOfStock = "OUT_OF_STOCK"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FSQuotaStatus(rawValue: raw) ?? .unknown
    }
}

struct FSQuotaResponse: Codable {
    let status: FSQuotaStatus?
    let max: Int?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        status = try values.decodeIfPresent(FSQuotaStatus.self, forKey: .status)
        max = try values.decodeIfPresent(Int.self, forKey: .max)
    }
}
`;

// Real subscript-decode shape, via this codebase's own KeyedDecodingContainer subscript extension
// (Common/BM_Extension/BM_KeyedDecodingContainerExtension.swift) — no type literal on the decode
// line at all, the type comes from the property's own declaration. Trimmed from the real
// AttachProductL3Info (SwiftPackages/BlibliSellerChatIOS/.../AttachProductModels.swift).
const SUBSCRIPT_CLASS = `
final class AttachProductL3Info: Codable, Equatable, Hashable, NSCopying {
    let cncActivated: Bool?
    let productName: String?
    let productImageUrl: URL?
    let itemData: AttachProductL3ItemData?
    var l4Products: [AttachProductL4Info]?
    var isProductExpanded: Bool = false
    var selectedL4ProductsCount: Int {
        return l4Products?.filter({ $0.isSelected == true }).count ?? 0
    }

    enum CodingKeys: CodingKey {
        case cncActivated, productName, productImageUrl, itemData
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cncActivated = values[.cncActivated]
        productName = values[.productName]
        productImageUrl = values[.productImageUrl]
        itemData = values[.itemData]
    }
}
`;

// Real subscript-decode shape with "self." and the "container" variable name, and no explicit raw
// values on CodingKeys. Trimmed from the real DigitalMobileConfig.swift.
const SUBSCRIPT_STRUCT_SELF = `
public struct DigitalMobileConfig: Codable {
    public let myBills: MyBills?
    var questConfig: [String: QuestConfig]?
    var cashBackToPoints: iOSVersion?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.myBills = container[.myBills]
        self.questConfig = container[.questConfig]
        self.cashBackToPoints = container[.cashBackToPoints]
    }
}
`;

const UNPARSED = `
struct FSOddResponse: Codable {
    let id: String?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        somethingElse = try values.decode(Int.self)
    }
}
`;

test("scalar fields with no CodingKeys remap", () => {
	const fields = parseDecodableFields(RANGE_ITEM, "FSSubFlashsaleRangeItemResponse");
	const start = fields.find((f) => f.name === "start");
	assert.deepEqual(start, { name: "start", jsonKey: "start", swiftType: "Double", isArray: false, isOptional: true, kind: "scalar" });
});

test("CodingKeys remap is honoured — isTimeBased decodes under wire key timeBased", () => {
	const fields = parseDecodableFields(RANGE_ITEM, "FSSubFlashsaleRangeItemResponse");
	const field = fields.find((f) => f.name === "isTimeBased");
	assert.equal(field.jsonKey, "timeBased");
	assert.notEqual(field.jsonKey, field.name);
});

test("a @SafeURL-wrapped property is scalar and optional even though it's decoded with decode(), not decodeIfPresent", () => {
	const fields = parseDecodableFields(RANGE_ITEM, "FSSubFlashsaleRangeItemResponse");
	const logo = fields.find((f) => f.name === "logo");
	assert.equal(logo.kind, "scalar");
	assert.equal(logo.isOptional, true);
	assert.equal(logo.jsonKey, "logo");
});

test("a nested same-file struct field is opaque, not recursed into", () => {
	const fields = parseDecodableFields(RANGE_ITEM, "FSSubFlashsaleRangeItemResponse");
	const background = fields.find((f) => f.name === "background");
	assert.equal(background.kind, "opaque");
	assert.equal(background.isArray, false);
	assert.match(background.skipReason, /not resolved/);
});

test("an array-of-struct field is opaque and isArray", () => {
	const fields = parseDecodableFields(RANGE_ITEM, "FSSubFlashsaleRangeItemResponse");
	const products = fields.find((f) => f.name === "products");
	assert.equal(products.kind, "opaque");
	assert.equal(products.isArray, true);
});

test("all 9 fields of the real pilot struct are found, in source order", () => {
	const fields = parseDecodableFields(RANGE_ITEM, "FSSubFlashsaleRangeItemResponse");
	assert.deepEqual(fields.map((f) => f.name), [
		"start", "end", "id", "isTimeBased", "logo", "subFlashsaleTitle", "subFlashsaleUrl", "background", "products",
	]);
});

test("a dictionary-valued field is opaque with a dictionary-specific reason, not treated as an array", () => {
	const fields = parseDecodableFields(SPECIAL_PLACEMENT, "FSSpecialPlacementResponse");
	const products = fields.find((f) => f.name === "products");
	assert.equal(products.kind, "opaque");
	assert.equal(products.isArray, false);
	assert.match(products.skipReason, /dictionary/);
});

test("a same-file raw-String enum field resolves its real cases, excluding the no-literal fallback", () => {
	const fields = parseDecodableFields(QUOTA, "FSQuotaResponse");
	const status = fields.find((f) => f.name === "status");
	assert.equal(status.kind, "enum");
	assert.deepEqual(status.enumCases, [
		{ name: "available", raw: "AVAILABLE" },
		{ name: "limited", raw: "LIMITED" },
		{ name: "outOfStock", raw: "OUT_OF_STOCK" },
	]);
});

test("an unparsable decode line is kept as kind \"unparsed\" with no jsonKey, and doesn't hide the other field", () => {
	const fields = parseDecodableFields(UNPARSED, "FSOddResponse");
	assert.equal(fields.length, 2);
	const id = fields.find((f) => f.name === "id");
	assert.equal(id.kind, "scalar");
	const odd = fields.find((f) => f.name !== "id");
	assert.equal(odd.kind, "unparsed");
	assert.equal(odd.jsonKey, null);
});

test("subscript decode (values[.x]): scalar type comes from the property's own declaration, not a .self literal", () => {
	const fields = parseDecodableFields(SUBSCRIPT_CLASS, "AttachProductL3Info");
	const cncActivated = fields.find((f) => f.name === "cncActivated");
	assert.deepEqual(cncActivated, { name: "cncActivated", jsonKey: "cncActivated", swiftType: "Bool?", isArray: false, isOptional: true, kind: "scalar" });
});

test("subscript decode: a nested/cross-file type field is opaque by the same rule as the explicit form", () => {
	const fields = parseDecodableFields(SUBSCRIPT_CLASS, "AttachProductL3Info");
	const itemData = fields.find((f) => f.name === "itemData");
	assert.equal(itemData.kind, "opaque");
	assert.match(itemData.skipReason, /not resolved/);
});

test("subscript decode: a computed property (trailing `{`) is never mistaken for a stored property's type", () => {
	const fields = parseDecodableFields(SUBSCRIPT_CLASS, "AttachProductL3Info");
	assert.equal(fields.find((f) => f.name === "selectedL4ProductsCount"), undefined, "it's not decoded at all, so it must not appear as a field");
});

test("subscript decode with \"self.\" and the container variable named \"container\": dictionary field still resolves as opaque", () => {
	const fields = parseDecodableFields(SUBSCRIPT_STRUCT_SELF, "DigitalMobileConfig");
	assert.deepEqual(fields.map((f) => f.name), ["myBills", "questConfig", "cashBackToPoints"]);
	const questConfig = fields.find((f) => f.name === "questConfig");
	assert.equal(questConfig.kind, "opaque");
	assert.match(questConfig.skipReason, /dictionary/);
});

test("subscript decode: a property with no CodingKeys remap uses its own name as the wire key", () => {
	const fields = parseDecodableFields(SUBSCRIPT_STRUCT_SELF, "DigitalMobileConfig");
	const myBills = fields.find((f) => f.name === "myBills");
	assert.equal(myBills.jsonKey, "myBills");
});

test("an unknown type name throws", () => {
	assert.throws(() => parseDecodableFields(RANGE_ITEM, "NoSuchType"), /no struct\/class\/enum named/);
});
