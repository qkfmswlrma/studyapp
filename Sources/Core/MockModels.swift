import Foundation

// ─────────────────────────────────────────────────────────
// 모의고사
//
// 표는 exam_records 와 exam_categories 다. 둘 다 본인 것만 읽고 쓴다.
// 남의 성적을 볼 이유가 없어서 서버 정책이 user_id = auth.uid() 로 막아뒀다.
// ─────────────────────────────────────────────────────────

/// 수능 시간표. 사이트의 SUBJECTS 와 같아야 한다 (_source.html 6938줄).
struct MockSubject: Identifiable, Hashable {
    let key: String
    let name: String
    let minutes: Int
    let count: Int
    let max: Int
    let at: String

    var id: String { key }

    static let all: [MockSubject] = [
        .init(key: "korean",  name: "국어",           minutes: 80,  count: 45, max: 100, at: "08:40~10:00"),
        .init(key: "math",    name: "수학",           minutes: 100, count: 30, max: 100, at: "10:30~12:10"),
        .init(key: "english", name: "영어",           minutes: 70,  count: 45, max: 100, at: "13:10~14:20"),
        .init(key: "history", name: "한국사",         minutes: 30,  count: 20, max: 50,  at: "14:50~15:20"),
        .init(key: "tamgu1",  name: "탐구 1",         minutes: 30,  count: 20, max: 50,  at: "15:35~16:05"),
        .init(key: "tamgu2",  name: "탐구 2",         minutes: 30,  count: 20, max: 50,  at: "16:07~16:37"),
        .init(key: "lang2",   name: "제2외국어·한문", minutes: 40,  count: 30, max: 50,  at: "17:05~17:45"),
    ]

    static func of(_ key: String) -> MockSubject {
        all.first { $0.key == key } ?? all[0]
    }

    /// 여기는 수학질문방이라 처음 고른 과목을 수학으로 둔다
    static let first = "math"

    /// 영어와 한국사는 절대평가라 백분위와 표준점수가 없다
    var hasPercentile: Bool { key != "english" && key != "history" }
}

/// 탐구는 사람마다 고른 과목이 달라서 계정에 적어둔 이름을 대신 쓴다.
enum TamguNames {
    static var first = ""
    static var second = ""

    static func apply(_ profile: Profile?) {
        first = (profile?.tamgu1 ?? "").trimmingCharacters(in: .whitespaces)
        second = (profile?.tamgu2 ?? "").trimmingCharacters(in: .whitespaces)
    }

    static func label(_ key: String) -> String {
        switch key {
        case "tamgu1": return first.isEmpty ? MockSubject.of(key).name : first
        case "tamgu2": return second.isEmpty ? MockSubject.of(key).name : second
        default:       return MockSubject.of(key).name
        }
    }
}

/// 튜플에는 키패스를 못 걸어서 ForEach 가 못 쓴다. 구조체로 둔다.
struct TamguGroup: Identifiable, Hashable {
    let group: String
    let items: [String]
    var id: String { group }
}

let TAMGU_CHOICES: [TamguGroup] = [
    .init(group: "사회탐구",
          items: ["생활과 윤리", "윤리와 사상", "한국지리", "세계지리", "동아시아사",
                  "세계사", "경제", "정치와 법", "사회·문화"]),
    .init(group: "과학탐구",
          items: ["물리학Ⅰ", "화학Ⅰ", "생명과학Ⅰ", "지구과학Ⅰ",
                  "물리학Ⅱ", "화학Ⅱ", "생명과학Ⅱ", "지구과학Ⅱ"]),
]

/// 평가원과 교육청 시험은 누가 봐도 같으니 처음부터 깔아둔다.
/// 사설처럼 사람마다 다른 건 exam_categories 에 각자 쌓인다.
let BASE_CATEGORIES = [
    "3월 학력평가", "5월 학력평가", "6월 모의평가",
    "7월 학력평가", "9월 모의평가", "10월 학력평가", "수능",
]

func isBaseCategory(_ name: String) -> Bool { BASE_CATEGORIES.contains(name) }

// ─────────────────────────────────────────────────────────
// 시험 이름 붙이고 쪼개기
//
// 저장은 합쳐진 이름 한 줄로 한다.
// 평가원과 교육청은 몇 년도 시험인지를 앞에 붙인다. 이건 응시일과 다르다.
// 2026년에 2024년 기출을 풀 수 있으니 따로 받아야 한다.
// 내가 만든 건 몇 회차인지를 뒤에 붙인다. "2024 6월 모의평가" "이감 3회"
// ─────────────────────────────────────────────────────────

struct ExamNameParts {
    var cat = ""
    var year = ""
    var round = ""
    /// 못 알아본 이름. 그대로 보여준다
    var orphan = ""
}

func composeExamName(_ p: ExamNameParts) -> String {
    if p.cat.isEmpty { return p.orphan }
    if isBaseCategory(p.cat) {
        return (p.year.isEmpty ? "" : p.year + " ") + p.cat
    }
    return p.cat + (p.round.isEmpty ? "" : " " + p.round + "회")
}

func parseExamName(_ name: String, myNames: [String]) -> ExamNameParts {
    let s = name.trimmingCharacters(in: .whitespaces)
    guard !s.isEmpty else { return ExamNameParts() }

    // "2024 6월 모의평가"
    if let space = s.firstIndex(of: " ") {
        let head = String(s[s.startIndex..<space])
        let tail = String(s[s.index(after: space)...])
        if head.count == 4, Int(head) != nil, isBaseCategory(tail) {
            return ExamNameParts(cat: tail, year: head)
        }
    }
    if isBaseCategory(s) { return ExamNameParts(cat: s) }

    // "이감 3회"
    if s.hasSuffix("회"), let space = s.lastIndex(of: " ") {
        let head = String(s[s.startIndex..<space])
        let tail = String(s[s.index(after: space)...].dropLast())
        if Int(tail) != nil, myNames.contains(head) {
            return ExamNameParts(cat: head, round: tail)
        }
    }
    if myNames.contains(s) { return ExamNameParts(cat: s) }
    return ExamNameParts(orphan: s)
}

/// 기출은 옛날 것도 푼다. 올해부터 거슬러 내려간다
var examYears: [String] {
    let now = Calendar.current.component(.year, from: Date())
    return stride(from: now, through: 2005, by: -1).map(String.init)
}

/// 이 분류로 몇 회차까지 적었는지 보고 다음 회차를 미리 골라준다
func suggestRound(_ records: [ExamRecord], cat: String) -> String {
    var maxRound = 0
    for r in records {
        guard r.examName.hasPrefix(cat + " ") else { continue }
        let rest = String(r.examName.dropFirst(cat.count + 1))
        guard rest.hasSuffix("회"), let n = Int(rest.dropLast()) else { continue }
        maxRound = Swift.max(maxRound, n)
    }
    return maxRound == 0 ? "" : String(maxRound + 1)
}

// ─────────────────────────────────────────────────────────
// 표
// ─────────────────────────────────────────────────────────

struct ExamRecord: Codable, Identifiable, Hashable {
    let id: UUID
    var userId: UUID?
    var examName: String
    /// 응시일. 날짜만 있고 시각은 없다
    var examDate: String
    var subject: String
    var detail: String
    var rawScore: Double?
    var stdScore: Double?
    var percentile: Double?
    var grade: Int?
    var wrongNos: [Int]
    /// 1등급컷부터 8등급컷까지의 원점수.
    ///
    /// **빈 칸이 섞일 수 있다.** 사이트는 아는 등급컷만 적게 해서
    /// 나머지 자리에 null 을 넣는다. `[Int]` 로 받으면 통째로 해석에 실패해
    /// 등급컷이 아예 없는 것처럼 되고 백분위 예상도 사라진다.
    var gradeCuts: [Int?]?
    var durationSec: Int?
    var memo: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, subject, detail, grade, memo, percentile
        case userId = "user_id"
        case examName = "exam_name"
        case examDate = "exam_date"
        case rawScore = "raw_score"
        case stdScore = "std_score"
        case wrongNos = "wrong_nos"
        case gradeCuts = "grade_cuts"
        case durationSec = "duration_sec"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try? c.decodeIfPresent(UUID.self, forKey: .userId)
        examName = (try? c.decodeIfPresent(String.self, forKey: .examName)) as? String ?? ""
        examDate = (try? c.decodeIfPresent(String.self, forKey: .examDate)) as? String ?? ""
        subject = (try? c.decodeIfPresent(String.self, forKey: .subject)) as? String ?? "math"
        detail = (try? c.decodeIfPresent(String.self, forKey: .detail)) as? String ?? ""
        rawScore = try? c.decodeIfPresent(Double.self, forKey: .rawScore)
        stdScore = try? c.decodeIfPresent(Double.self, forKey: .stdScore)
        percentile = try? c.decodeIfPresent(Double.self, forKey: .percentile)
        grade = try? c.decodeIfPresent(Int.self, forKey: .grade)
        wrongNos = (try? c.decodeIfPresent([Int].self, forKey: .wrongNos)) as? [Int] ?? []
        gradeCuts = try? c.decodeIfPresent([Int?].self, forKey: .gradeCuts)
        durationSec = try? c.decodeIfPresent(Int.self, forKey: .durationSec)
        memo = (try? c.decodeIfPresent(String.self, forKey: .memo)) as? String ?? ""
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    var subjectLabel: String { TamguNames.label(subject) }
    var subjectInfo: MockSubject { MockSubject.of(subject) }
}

/// 새로 적거나 고칠 때 보내는 몸통. 서버가 붙이는 값은 뺀다.
struct ExamRecordInput: Encodable {
    var user_id: UUID
    var exam_name: String
    var exam_date: String
    var subject: String
    var detail: String
    var raw_score: Double?
    var std_score: Double?
    var percentile: Double?
    var grade: Int?
    var wrong_nos: [Int]
    var grade_cuts: [Int?]?
    var duration_sec: Int?
    var memo: String
}

struct ExamCategory: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    /// 비어 있으면 전 과목, 값이 있으면 그 과목에서만 보인다
    var subject: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, subject
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) as? String ?? ""
        subject = try? c.decodeIfPresent(String.self, forKey: .subject)
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

// ─────────────────────────────────────────────────────────
// 게임 랭킹
// ─────────────────────────────────────────────────────────

struct SpeedRank: Codable, Identifiable, Hashable {
    let nickname: String
    let bestScore: Int
    var id: String { nickname }

    enum CodingKeys: String, CodingKey {
        case nickname
        case bestScore = "best_score"
    }
}

struct MySpeedRank: Codable {
    let myRank: Int
    let bestScore: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case myRank = "my_rank"
        case bestScore = "best_score"
        case total
    }
}
