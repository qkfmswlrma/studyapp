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

    /// 사이트의 `emailOf` 와 같아야 한다 (_source.html 95줄).
    /// **소문자로 바꾸는 것을 빼먹으면 안 된다.** 대문자가 섞인 아이디로 가입한 사람이
    /// 앱에서만 로그인이 안 된다.
    static func email(for username: String) -> String {
        "\(username.trimmingCharacters(in: .whitespaces).lowercased())@\(emailDomain)"
    }

    /// 사이트의 `padPw` 와 같아야 한다 (_source.html 96줄).
    ///
    /// 사이트는 비밀번호 뒤에 이 꼬리를 붙여서 Supabase 에 보낸다.
    /// **붙이지 않으면 사이트에서 가입한 사람이 앱에서 로그인되지 않고,
    /// 앱에서 가입한 사람이 사이트에서 로그인되지 않는다.**
    /// 서버의 비밀번호 초기화도 `0000__mr__` 로 넣는다.
    static func password(_ raw: String) -> String { raw + "__mr__" }

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

    /// 비회원 제출. 표를 직접 못 쓰고 이 함수로만 들어간다.
    /// 서버가 IP 로 하루 한 번만 받아준다.
    static func submitGuest(examId: UUID, answers: [String: JSONValue]) async throws {
        struct Params: Encodable {
            let p_exam_id: UUID
            let p_answers: [String: JSONValue]
        }
        try await client
            .rpc("submit_guest_attempt", params: Params(p_exam_id: examId, p_answers: answers))
            .execute()
    }

    // ── 계정 ────────────────────────────────────────────

    static func changePassword(_ newPassword: String) async throws {
        _ = try await client.auth.update(
            user: UserAttributes(password: password(newPassword)))
    }

    static func updateKakaoId(_ value: String, userId: UUID) async throws {
        struct Patch: Encodable { let kakao_id: String }
        try await client.from("profiles")
            .update(Patch(kakao_id: value.trimmingCharacters(in: .whitespaces)))
            .eq("id", value: userId)
            .execute()
    }

    /// 탈퇴. 되돌릴 수 없다.
    static func deleteMyAccount() async throws {
        try await client.rpc("delete_my_account").execute()
    }

    // ── 안 읽음 표시 ────────────────────────────────────

    static func readPostIds() async throws -> Set<UUID> {
        struct Row: Decodable { let column_id: UUID }
        let rows: [Row] = try await client.from("column_reads")
            .select("column_id").execute().value
        return Set(rows.map(\.column_id))
    }

    static func readExamIds() async throws -> Set<UUID> {
        struct Row: Decodable { let exam_id: UUID }
        let rows: [Row] = try await client.from("exam_reads")
            .select("exam_id").execute().value
        return Set(rows.map(\.exam_id))
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

// ─────────────────────────────────────────────────────────
// 모의고사
//
// 전부 본인 것만 읽고 쓴다. 서버 정책이 user_id = auth.uid() 로 막고 있어서
// 앱에서 남의 것을 부르려 해도 빈 값만 온다.
// ─────────────────────────────────────────────────────────

extension Supa {

    static func examRecords() async throws -> [ExamRecord] {
        try await client.from("exam_records")
            .select()
            .order("exam_date", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func addExamRecord(_ input: ExamRecordInput) async throws -> ExamRecord? {
        let rows: [ExamRecord] = try await client.from("exam_records")
            .insert(input).select().execute().value
        return rows.first
    }

    static func updateExamRecord(id: UUID, _ input: ExamRecordInput) async throws {
        try await client.from("exam_records")
            .update(input).eq("id", value: id).execute()
    }

    static func deleteExamRecord(id: UUID) async throws {
        try await client.from("exam_records").delete().eq("id", value: id).execute()
    }

    static func examCategories() async throws -> [ExamCategory] {
        try await client.from("exam_categories")
            .select()
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func addExamCategory(name: String, subject: String?, userId: UUID) async throws {
        struct Row: Encodable {
            let user_id: UUID
            let name: String
            let subject: String?
        }
        try await client.from("exam_categories")
            .insert(Row(user_id: userId, name: name, subject: subject))
            .execute()
    }

    static func deleteExamCategory(id: UUID) async throws {
        try await client.from("exam_categories").delete().eq("id", value: id).execute()
    }

    /// 탐구 과목 이름. 사람마다 고른 과목이 달라서 계정에 적어둔다.
    static func updateTamgu(_ first: String, _ second: String, userId: UUID) async throws {
        struct Patch: Encodable { let tamgu1: String?; let tamgu2: String? }
        let clean: (String) -> String? = {
            let v = $0.trimmingCharacters(in: .whitespaces)
            return v.isEmpty ? nil : v
        }
        try await client.from("profiles")
            .update(Patch(tamgu1: clean(first), tamgu2: clean(second)))
            .eq("id", value: userId)
            .execute()
    }
}

// ─────────────────────────────────────────────────────────
// 게임 랭킹
//
// 점수는 표에 바로 못 쓴다. 브라우저 콘솔로 아무 값이나 넣지 못하게
// 서버 함수가 정답 수와 걸린 시간으로 검산한 뒤에 받아준다.
// ─────────────────────────────────────────────────────────

extension Supa {

    static func speedRanking(limit: Int = 50) async throws -> [SpeedRank] {
        try await client.rpc("speed_ranking", params: ["p_limit": limit])
            .execute().value
    }

    static func mySpeedRank() async throws -> MySpeedRank? {
        let rows: [MySpeedRank] = try await client.rpc("my_speed_rank").execute().value
        return rows.first
    }

    /// 점수를 올린다. 채팅방 닉네임이 없으면 서버가 거절한다.
    static func submitSpeedScore(score: Int, correct: Int,
                                 combo: Int, seconds: Double) async throws {
        struct Params: Encodable {
            let p_score: Int
            let p_correct: Int
            let p_combo: Int
            let p_seconds: Double
        }
        try await client
            .rpc("submit_speed_score",
                 params: Params(p_score: score, p_correct: correct,
                                p_combo: combo, p_seconds: seconds))
            .execute()
    }
}

// ─────────────────────────────────────────────────────────
// 관리자
//
// 화면에서 감추는 것과 실제로 막는 것은 다르다.
// 여기 있는 것들은 전부 서버가 is_admin() 과 is_root() 로 한 번 더 판정한다.
// 앱이 잘못 불러도 서버가 거절한다.
// ─────────────────────────────────────────────────────────

extension Supa {

    /// 회원 목록. 정책이 관리자에게만 남의 프로필을 보여준다.
    static func allProfiles() async throws -> [Profile] {
        try await client.from("profiles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// 제출 전체. 채점 화면이 쓴다.
    static func allSubmissions() async throws -> [Submission] {
        try await client.from("submissions")
            .select()
            .order("submitted_at", ascending: false)
            .execute()
            .value
    }

    static func auditLog(limit: Int = 200) async throws -> [AuditEntry] {
        try await client.from("audit_log")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    static func log(action: String, target: String, actor: String, actorId: UUID) async throws {
        struct Row: Encodable {
            let actor: String
            let actor_id: UUID
            let action: String
            let target: String
        }
        try await client.from("audit_log")
            .insert(Row(actor: actor, actor_id: actorId, action: action, target: target))
            .execute()
    }

    // ── 칼럼과 공지 ─────────────────────────────────────

    static func savePost(_ input: PostInput) async throws {
        try await client.from("columns").insert(input).execute()
    }

    static func updatePost(id: UUID, _ patch: PostPatch) async throws {
        try await client.from("columns").update(patch).eq("id", value: id).execute()
    }

    static func deletePost(id: UUID) async throws {
        try await client.from("columns").delete().eq("id", value: id).execute()
    }

    // ── 출제 ────────────────────────────────────────────
    //
    // 쓸 때는 exams 표에 직접 넣는다. exams_view 는 읽기 전용이다.

    static func saveExam(_ input: ExamInput) async throws {
        try await client.from("exams").insert(input).execute()
    }

    static func updateExam(id: UUID, _ input: ExamPatch) async throws {
        try await client.from("exams").update(input).eq("id", value: id).execute()
    }

    static func deleteExam(id: UUID) async throws {
        try await client.from("exams").delete().eq("id", value: id).execute()
    }

    /// 사람이 매긴 점수를 저장한다.
    static func gradeSubmission(id: UUID, scores: [String: JSONValue]) async throws {
        struct Patch: Encodable {
            let manual_scores: [String: JSONValue]
            let graded: Bool
        }
        try await client.from("submissions")
            .update(Patch(manual_scores: scores, graded: true))
            .eq("id", value: id)
            .execute()
    }

    // ── 회원 관리 (root 전용) ───────────────────────────
    //
    // 이 화면 자체를 root 에게만 보여준다. 서버도 is_root() 로 막는다.

    static func setAdmin(username: String, on: Bool) async throws {
        struct Patch: Encodable { let is_admin: Bool }
        try await client.from("profiles")
            .update(Patch(is_admin: on))
            .eq("username", value: username)
            .execute()
    }

    static func deleteUser(username: String) async throws {
        try await client.rpc("admin_delete_user",
                             params: ["p_username": username]).execute()
    }

    static func resetPassword(username: String) async throws {
        try await client.rpc("admin_reset_password",
                             params: ["p_username": username]).execute()
    }
}

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let m): return m }
    }
}
