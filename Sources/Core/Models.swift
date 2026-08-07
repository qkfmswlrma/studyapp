import Foundation

// ─────────────────────────────────────────────────────────
// DB 열 이름은 snake_case, 스위프트는 camelCase 라 CodingKeys 로 잇는다.
// 사이트의 mapColumn / mapExam / mapProfile 이 하던 일과 같다.
// 여기 없는 열은 앱에서 존재하지 않는 값이 되므로, 새 열을 쓰려면 여기부터 고친다.
// ─────────────────────────────────────────────────────────

struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String
    var kakaoId: String
    var isAdmin: Bool
    var isSuper: Bool
    var tamgu1: String?
    var tamgu2: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username
        case kakaoId = "kakao_id"
        case isAdmin = "is_admin"
        case isSuper = "is_super"
        case tamgu1, tamgu2
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        kakaoId = (try? c.decodeIfPresent(String.self, forKey: .kakaoId)) as? String ?? ""
        isAdmin = (try? c.decode(Bool.self, forKey: .isAdmin)) ?? false
        isSuper = (try? c.decode(Bool.self, forKey: .isSuper)) ?? false
        tamgu1 = try? c.decodeIfPresent(String.self, forKey: .tamgu1)
        tamgu2 = try? c.decodeIfPresent(String.self, forKey: .tamgu2)
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

// ─────────────────────────────────────────────────────────
// 칼럼과 공지는 같은 표(columns)를 쓴다. category = 'notice' 인 것이 공지다.
// ─────────────────────────────────────────────────────────

enum PostCategory: String, Codable, CaseIterable {
    case elem, mid, high, notice

    var label: String {
        switch self {
        case .elem: return "초등"
        case .mid: return "중학"
        case .high: return "고등"
        case .notice: return "공지"
        }
    }
}

struct Post: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var body: String
    var author: String
    var authorId: UUID?
    var category: PostCategory
    var isDraft: Bool
    var isRule: Bool
    var sortOrder: Int
    var no: Int?
    var prevNos: [Int]
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, body, author, category, no
        case authorId = "author_id"
        case isDraft = "is_draft"
        case isRule = "is_rule"
        case sortOrder = "sort_order"
        case prevNos = "prev_nos"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        body = (try? c.decodeIfPresent(String.self, forKey: .body)) as? String ?? ""
        author = (try? c.decodeIfPresent(String.self, forKey: .author)) as? String ?? ""
        authorId = try? c.decodeIfPresent(UUID.self, forKey: .authorId)
        category = (try? c.decode(PostCategory.self, forKey: .category)) ?? .elem
        isDraft = (try? c.decode(Bool.self, forKey: .isDraft)) ?? false
        isRule = (try? c.decode(Bool.self, forKey: .isRule)) ?? false
        sortOrder = (try? c.decode(Int.self, forKey: .sortOrder)) ?? 0
        no = try? c.decodeIfPresent(Int.self, forKey: .no)
        prevNos = (try? c.decodeIfPresent([Int].self, forKey: .prevNos)) as? [Int] ?? []
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    /// 글번호로 찾을 때는 옛 번호도 같이 본다.
    /// 분류가 바뀌면 새 번호를 받고 옛 번호는 prev_nos 에 남는다.
    /// **자릿수를 해석하면 안 된다.** 값으로만 찾는다.
    func matches(no target: Int) -> Bool {
        no == target || prevNos.contains(target)
    }
}

// ─────────────────────────────────────────────────────────
// 시험
// ─────────────────────────────────────────────────────────

enum ExamType: String, Codable {
    case level, today

    var label: String {
        switch self {
        case .level: return "레벨테스트"
        case .today: return "오늘의 문제"
        }
    }
}

/// 문제 본문은 글과 수식이 섞인 조각들의 줄이다.
/// boxstart 와 boxend 사이는 조건 박스 안에 들어간다.
enum BodyBlock: Codable, Hashable {
    case text(String)
    case math(String)
    case boxStart
    case boxEnd

    enum CodingKeys: String, CodingKey { case type, v, latex }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? c.decode(String.self, forKey: .type)) ?? "text"
        switch type {
        case "boxstart": self = .boxStart
        case "boxend":   self = .boxEnd
        case "math":     self = .math((try? c.decode(String.self, forKey: .latex)) ?? "")
        default:         self = .text((try? c.decode(String.self, forKey: .v)) ?? "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let v):  try c.encode("text", forKey: .type); try c.encode(v, forKey: .v)
        case .math(let l):  try c.encode("math", forKey: .type); try c.encode(l, forKey: .latex)
        case .boxStart:     try c.encode("boxstart", forKey: .type)
        case .boxEnd:       try c.encode("boxend", forKey: .type)
        }
    }
}

enum QuestionType: String, Codable {
    case mc     // 객관식
    case short  // 주관식
}

struct Question: Codable, Identifiable, Hashable {
    let id: String
    var type: QuestionType
    var points: Double
    var body: [BodyBlock]
    var options: [String]
    var image: String?

    /// 정답. 아직 안 푼 사람에게는 서버(exams_view)가 지우고 준다.
    var answer: Int?
    var accept: String?
    var explain: [BodyBlock]?

    /// 옛 문제는 body 대신 latex/text 를 쓴다.
    var latex: String?
    var text: String?

    enum CodingKeys: String, CodingKey {
        case id, type, points, body, options, image, answer, accept, explain, latex, text
    }

    /// 새로 만들 때. 사용자 정의 init(from:) 이 있으면 기본 생성자가 안 만들어져서 여기 둔다.
    /// **id 는 채점이 답을 찾는 열쇠다.** 문항마다 달라야 한다.
    init(id: String = String(UUID().uuidString.prefix(8)),
         type: QuestionType = .mc,
         points: Double = 0,
         body: [BodyBlock] = [],
         options: [String] = ["", ""]) {
        self.id = id
        self.type = type
        self.points = points
        self.body = body
        self.options = options
        self.image = nil
        self.answer = nil
        self.accept = nil
        self.explain = nil
        self.latex = nil
        self.text = nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        type = (try? c.decode(QuestionType.self, forKey: .type)) ?? .mc
        points = (try? c.decode(Double.self, forKey: .points))
            ?? Double((try? c.decode(String.self, forKey: .points)) ?? "") ?? 0
        body = (try? c.decodeIfPresent([BodyBlock].self, forKey: .body)) as? [BodyBlock] ?? []
        options = (try? c.decodeIfPresent([String].self, forKey: .options)) as? [String] ?? []
        image = try? c.decodeIfPresent(String.self, forKey: .image)
        answer = try? c.decodeIfPresent(Int.self, forKey: .answer)
        accept = try? c.decodeIfPresent(String.self, forKey: .accept)
        explain = try? c.decodeIfPresent([BodyBlock].self, forKey: .explain)
        latex = try? c.decodeIfPresent(String.self, forKey: .latex)
        text = try? c.decodeIfPresent(String.self, forKey: .text)
    }

    var hasExplain: Bool { !(explain ?? []).isEmpty }
}

struct Exam: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var questions: [Question]
    var author: String
    var authorId: UUID?
    var examType: ExamType
    var publishAt: Date?
    var no: Int?
    var prevNos: [Int]
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, questions, author, no
        case authorId = "author_id"
        case examType = "exam_type"
        case publishAt = "publish_at"
        case prevNos = "prev_nos"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        questions = (try? c.decodeIfPresent([Question].self, forKey: .questions)) as? [Question] ?? []
        author = (try? c.decodeIfPresent(String.self, forKey: .author)) as? String ?? ""
        authorId = try? c.decodeIfPresent(UUID.self, forKey: .authorId)
        examType = (try? c.decode(ExamType.self, forKey: .examType)) ?? .level
        publishAt = try? c.decodeIfPresent(Date.self, forKey: .publishAt)
        no = try? c.decodeIfPresent(Int.self, forKey: .no)
        prevNos = (try? c.decodeIfPresent([Int].self, forKey: .prevNos)) as? [Int] ?? []
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    func matches(no target: Int) -> Bool {
        no == target || prevNos.contains(target)
    }

    var maxScore: Double { questions.reduce(0) { $0 + $1.points } }

    /// 정답이 지워진 채로 내려왔는지. 서버는 아직 안 푼 사람에게 정답을 빼고 준다.
    var answersHidden: Bool {
        guard !questions.isEmpty else { return false }
        return questions.allSatisfy { $0.answer == nil && $0.accept == nil }
    }

    /// 제출한 뒤 서버가 정답을 붙여 다시 내려주면 문항에 합친다.
    func merging(answersFrom fresh: [Question]) -> Exam {
        guard !fresh.isEmpty else { return self }
        var byId: [String: Question] = [:]
        for q in fresh { byId[q.id] = q }
        var copy = self
        copy.questions = questions.map { q in
            guard let f = byId[q.id] else { return q }
            var merged = q
            merged.answer = f.answer
            merged.accept = f.accept
            merged.explain = f.explain
            return merged
        }
        return copy
    }
}

// ─────────────────────────────────────────────────────────
// 제출
// ─────────────────────────────────────────────────────────

struct Submission: Codable, Identifiable, Hashable {
    let id: UUID
    var examId: UUID?
    var student: String
    var studentId: UUID?
    var answers: [String: JSONValue]
    var manualScores: [String: JSONValue]
    var graded: Bool
    var submittedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, student, answers, graded
        case examId = "exam_id"
        case studentId = "student_id"
        case manualScores = "manual_scores"
        case submittedAt = "submitted_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        examId = try? c.decodeIfPresent(UUID.self, forKey: .examId)
        student = (try? c.decodeIfPresent(String.self, forKey: .student)) as? String ?? ""
        studentId = try? c.decodeIfPresent(UUID.self, forKey: .studentId)
        answers = (try? c.decodeIfPresent([String: JSONValue].self, forKey: .answers)) as? [String: JSONValue] ?? [:]
        manualScores = (try? c.decodeIfPresent([String: JSONValue].self, forKey: .manualScores)) as? [String: JSONValue] ?? [:]
        graded = (try? c.decode(Bool.self, forKey: .graded)) ?? false
        submittedAt = try? c.decodeIfPresent(Date.self, forKey: .submittedAt)
    }
}

/// 새 제출을 보낼 때 쓰는 몸통. id 와 시각은 서버가 붙인다.
struct NewSubmission: Encodable {
    let exam_id: UUID
    let student: String
    let student_id: UUID
    let answers: [String: JSONValue]
}

// ─────────────────────────────────────────────────────────
// 출제
// ─────────────────────────────────────────────────────────

/// 새 시험. 글번호는 서버 트리거가 붙이므로 보내지 않는다.
struct ExamInput: Encodable {
    let title: String
    let questions: [Question]
    let author: String
    let author_id: UUID
    let exam_type: String
    let publish_at: Date?
}

/// 고칠 때. 글쓴이는 바꾸지 않는다.
struct ExamPatch: Encodable {
    let title: String
    let questions: [Question]
    let exam_type: String
    let publish_at: Date?
}

// ─────────────────────────────────────────────────────────
// 칼럼과 공지 쓰기
// ─────────────────────────────────────────────────────────

struct PostInput: Encodable {
    let title: String
    let body: String
    let author: String
    let author_id: UUID
    let category: String
    let is_draft: Bool
    let is_rule: Bool
}

struct PostPatch: Encodable {
    let title: String
    let body: String
    let category: String
    let is_draft: Bool
    let is_rule: Bool
}

// ─────────────────────────────────────────────────────────
// 활동 기록
// ─────────────────────────────────────────────────────────

struct AuditEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var actor: String
    var action: String
    var target: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, actor, action, target
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        actor = (try? c.decodeIfPresent(String.self, forKey: .actor)) as? String ?? ""
        action = (try? c.decodeIfPresent(String.self, forKey: .action)) as? String ?? ""
        target = (try? c.decodeIfPresent(String.self, forKey: .target)) as? String ?? ""
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    /// 회원 관리 기록. 일반 관리자에게는 걸러서 보여준다.
    static let memberActions = ["관리자 지정", "관리자 해제", "회원 삭제", "비밀번호 초기화"]
    var isMemberAction: Bool { AuditEntry.memberActions.contains(action) }
}

// ─────────────────────────────────────────────────────────
// 정답률. 앱에서 계산하지 않고 서버 함수가 준 값을 그대로 쓴다.
// 학생은 남의 제출을 못 읽어서 앱에서 세면 자기 것만 반영된다.
// ─────────────────────────────────────────────────────────

struct QuestionStat: Codable {
    let qid: String
    let total: Int
    let correct: Int
    let gtotal: Int
    let gcorrect: Int

    /// 회원과 비회원을 합쳐서 낸다.
    var rate: Double? {
        let all = total + gtotal
        guard all > 0 else { return nil }
        return Double(correct + gcorrect) / Double(all)
    }
}

struct ExamStat: Codable {
    let examId: UUID
    let total: Int
    let correct: Int
    let gtotal: Int
    let gcorrect: Int

    enum CodingKeys: String, CodingKey {
        case examId = "exam_id"
        case total, correct, gtotal, gcorrect
    }

    var rate: Double? {
        let all = total + gtotal
        guard all > 0 else { return nil }
        return Double(correct + gcorrect) / Double(all)
    }
}
