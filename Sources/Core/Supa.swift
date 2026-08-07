import Foundation
import Supabase

/// 사이트와 **같은** Supabase 를 본다. 주소도 키도 사이트(_source.html 66~68줄)와 같다.
/// 표와 정책은 하나도 안 바꾼다. 권한은 서버의 RLS 와 is_admin(), is_root() 가 판정하므로
/// 앱을 새로 짜도 규칙이 그대로 따라온다.
enum Supa {
    static let url = URL(string: "https://fhdwwqlvosbjonrenpqz.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZoZHd3cWx2b3Niam9ucmVucHF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzMTk4NzYsImV4cCI6MjA5NTg5NTg3Nn0.JgUEKxDRioqKvhSaOPxJMH9tuo0wdFv0-kkc0s5mJ8U"

    /// 사이트는 아이디만 받고 뒤에 이 도메인을 붙여 이메일 로그인을 쓴다.
    /// 앱도 똑같이 해야 사이트에서 가입한 사람이 그대로 로그인된다.
    static let emailDomain = "mathroom.app"

    static func email(for username: String) -> String {
        "\(username.trimmingCharacters(in: .whitespaces))@\(emailDomain)"
    }

    static let client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: .init(
                db: .init(encoder: encoder, decoder: decoder)
            )
        )
    }()

    /// Postgres 의 timestamptz 는 소수 자리가 있을 때도 없을 때도 있다.
    /// 둘 다 받아주지 않으면 목록이 통째로 안 읽힌다.
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = isoWithFraction.date(from: s) { return date }
            if let date = isoPlain.date(from: s) { return date }
            if let date = dateOnly.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "날짜를 못 읽었습니다: \(s)"))
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(isoWithFraction.string(from: date))
        }
        return e
    }()

    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// ─────────────────────────────────────────────────────────
// 읽기
// ─────────────────────────────────────────────────────────

extension Supa {

    /// 칼럼과 공지는 같은 표를 쓴다. category = 'notice' 인 것이 공지다.
    /// 공지는 누구나, 칼럼은 로그인한 사람만 읽을 수 있게 서버 정책이 걸려 있다.
    static func posts() async throws -> [Post] {
        try await client.from("columns")
            .select()
            .order("sort_order", ascending: true)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// **exams 가 아니라 exams_view 를 읽는다.**
    /// 아직 안 푼 사람에게는 서버가 정답과 해설을 지우고 준다.
    /// 표를 직접 읽으면 정답이 딸려 와서 앱에서 다 보인다.
    static func exams() async throws -> [Exam] {
        try await client.from("exams_view")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// 제출한 뒤에 정답이 붙은 시험을 다시 받아온다. 채점 화면이 쓴다.
    static func exam(id: UUID) async throws -> Exam? {
        let rows: [Exam] = try await client.from("exams_view")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func mySubmissions() async throws -> [Submission] {
        try await client.from("submissions")
            .select()
            .order("submitted_at", ascending: false)
            .execute()
            .value
    }

    static func profile(id: UUID) async throws -> Profile? {
        let rows: [Profile] = try await client.from("profiles")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// 시험별 정답률을 한 번에. 목록에서 시험마다 부르면 느리다.
    static func allExamStats() async throws -> [UUID: ExamStat] {
        let rows: [ExamStat] = try await client.rpc("exam_stats_all").execute().value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.examId, $0) })
    }

    /// 한 시험의 문항별 정답률.
    static func questionStats(examId: UUID) async throws -> [String: QuestionStat] {
        let rows: [QuestionStat] = try await client
            .rpc("exam_question_stats", params: ["p_exam_id": examId.uuidString])
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.qid, $0) })
    }
}

// ─────────────────────────────────────────────────────────
// 쓰기
// ─────────────────────────────────────────────────────────

extension Supa {

    static func submit(examId: UUID, student: String, studentId: UUID,
                       answers: [String: JSONValue]) async throws -> Submission {
        let body = NewSubmission(exam_id: examId, student: student,
                                 student_id: studentId, answers: answers)
        let rows: [Submission] = try await client.from("submissions")
            .insert(body)
            .select()
            .execute()
            .value
        guard let row = rows.first else {
            throw AppError.message("제출이 저장되지 않았습니다.")
        }
        return row
    }

    /// 읽음 표시. 안 읽은 글에 붙는 점을 없앤다.
    static func markRead(postId: UUID, userId: UUID) async throws {
        struct Row: Encodable { let user_id: UUID; let column_id: UUID }
        try await client.from("column_reads")
            .upsert(Row(user_id: userId, column_id: postId))
            .execute()
    }

    static func markRead(examId: UUID, userId: UUID) async throws {
        struct Row: Encodable { let user_id: UUID; let exam_id: UUID }
        try await client.from("exam_reads")
            .upsert(Row(user_id: userId, exam_id: examId))
            .execute()
    }
}

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let m): return m }
    }
}
