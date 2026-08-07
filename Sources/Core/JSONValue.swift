import Foundation

/// 제출한 답은 문항 종류에 따라 숫자이기도 하고 글자이기도 하다.
/// 객관식은 고른 번호(정수), 주관식은 적어 넣은 값(글자)이다.
/// 한 칸에 두 종류가 섞여 들어오므로 그대로 담을 수 있는 그릇이 필요하다.
enum JSONValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .null:          try c.encodeNil()
        }
    }

    /// 주관식 비교와 화면 표시에 쓴다.
    var asString: String {
        switch self {
        case .string(let v): return v
        case .int(let v):    return String(v)
        case .double(let v): return v == v.rounded() ? String(Int(v)) : String(v)
        case .bool(let v):   return v ? "true" : "false"
        case .null:          return ""
        }
    }

    /// 객관식에서 고른 번호. 글자로 들어온 옛 자료도 받아준다.
    var asInt: Int? {
        switch self {
        case .int(let v):    return v
        case .double(let v): return Int(v)
        case .string(let v): return Int(v)
        default:             return nil
        }
    }

    var asDouble: Double? {
        switch self {
        case .int(let v):    return Double(v)
        case .double(let v): return v
        case .string(let v): return Double(v)
        default:             return nil
        }
    }

    var isEmpty: Bool {
        if case .null = self { return true }
        return asString.isEmpty
    }
}
