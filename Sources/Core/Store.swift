import Foundation
import Supabase

/// 앱이 들고 있는 상태를 한곳에 모은다.
/// 화면마다 따로 불러오면 같은 값이 화면마다 달라진다.
@MainActor
final class Store: ObservableObject {

    @Published var profile: Profile?
    @Published var posts: [Post] = []
    @Published var exams: [Exam] = []
    @Published var submissions: [Submission] = []
    @Published var examStats: [UUID: ExamStat] = [:]
    @Published var readPosts: Set<UUID> = []
    @Published var readExams: Set<UUID> = []

    /// 모의고사. 서버 정책이 본인 것만 내려준다.
    @Published var examRecords: [ExamRecord] = []
    @Published var examCategories: [ExamCategory] = []

    @Published var loading = true
    @Published var errorText: String?

    var loggedIn: Bool { profile != nil }
    var isAdmin: Bool { profile?.isAdmin == true }
    /// root 는 화면 어디에도 드러내지 않는다. 이 값으로 화면 자체를 감춘다.
    var isRoot: Bool { profile?.isSuper == true }

    var notices: [Post] {
        // 채팅방 규칙은 순서와 상관없이 맨 위로 온다
        posts.filter { $0.category == .notice && !$0.isDraft }
            .sorted { a, b in
                if a.isRule != b.isRule { return a.isRule }
                if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
                return (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
            }
    }

    func columns(_ category: PostCategory?) -> [Post] {
        posts.filter { p in
            guard p.category != .notice, !p.isDraft else { return false }
            guard let category else { return true }
            return p.category == category
        }
    }

    func exams(of type: ExamType) -> [Exam] {
        exams.filter { $0.examType == type }
    }

    func mySubmission(examId: UUID) -> Submission? {
        submissions.first { $0.examId == examId }
    }

    // ── 오늘의 문제 ─────────────────────────────────────

    /// 그날 낸 문제. 공개 시각이 없으면 만든 날로 본다.
    func dailyExam(on date: Date) -> Exam? {
        let cal = Calendar.current
        return exams(of: .today).first { exam in
            guard let day = exam.publishAt ?? exam.createdAt else { return false }
            return cal.isDate(day, inSameDayAs: date)
        }
    }

    /// 며칠 연속으로 풀었는지.
    ///
    /// 오늘 것을 아직 안 풀었어도 어제까지 이어졌으면 끊기지 않은 것으로 센다.
    /// 하루가 다 가기 전에 연속이 끊긴 것처럼 보이면 안 된다.
    /// **문제가 없던 날은 건너뛴다.** 안 낸 날 때문에 기록이 끊기면 억울하다.
    var dailyStreak: Int {
        guard loggedIn else { return 0 }
        let cal = Calendar.current
        var count = 0
        var day = Date()

        // 오늘 것을 아직 안 풀었으면 어제부터 센다
        if let today = dailyExam(on: day), mySubmission(examId: today.id) == nil {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        // 너무 옛날까지 훑지 않는다. 400일이면 충분하다
        for _ in 0..<400 {
            if let exam = dailyExam(on: day) {
                guard mySubmission(examId: exam.id) != nil else { break }
                count += 1
            }
            guard let before = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = before
        }
        return count
    }

    /// 내가 쓴 글은 내가, 남이 쓴 것은 root 만 고친다.
    func canEdit(_ post: Post) -> Bool {
        guard isAdmin else { return false }
        return isRoot || post.authorId == profile?.id
    }

    func deletePost(_ post: Post) async {
        do {
            try await Supa.deletePost(id: post.id)
            posts.removeAll { $0.id == post.id }
            if let me = profile {
                try? await Supa.log(action: "글 삭제", target: post.title,
                                    actor: me.username, actorId: me.id)
            }
        } catch {
            errorText = friendly(error)
        }
    }

    /// 내가 낸 시험은 내가, 남이 낸 것은 root 만 고친다.
    /// 서버 정책도 같아서 앱이 잘못 불러도 거절당한다.
    func canEdit(_ exam: Exam) -> Bool {
        guard isAdmin else { return false }
        return isRoot || exam.authorId == profile?.id
    }

    func deleteExam(_ exam: Exam) async {
        do {
            try await Supa.deleteExam(id: exam.id)
            exams.removeAll { $0.id == exam.id }
            if let me = profile {
                try? await Supa.log(action: "시험 삭제", target: exam.title,
                                    actor: me.username, actorId: me.id)
            }
        } catch {
            errorText = friendly(error)
        }
    }

    // ── 불러오기 ────────────────────────────────────────

    func bootstrap() async {
        loading = true
        await refreshSession()
        await reload()
        loading = false
    }

    /// 앱을 껐다 켜도 로그인이 풀리지 않는다. 세션은 Keychain 에 있다.
    func refreshSession() async {
        do {
            let session = try await Supa.client.auth.session
            profile = try await Supa.profile(id: session.user.id)
        } catch {
            profile = nil
        }
        // 탐구 과목 이름은 화면 곳곳에서 쓴다. 프로필이 바뀔 때마다 갱신한다.
        TamguNames.apply(profile)
    }

    // ── 모의고사 ────────────────────────────────────────

    func loadMock() async {
        guard loggedIn else {
            examRecords = []
            examCategories = []
            return
        }
        examRecords = (try? await Supa.examRecords()) ?? []
        examCategories = (try? await Supa.examCategories()) ?? []
    }

    func deleteExamRecord(_ record: ExamRecord) async {
        do {
            try await Supa.deleteExamRecord(id: record.id)
            examRecords.removeAll { $0.id == record.id }
        } catch {
            errorText = friendly(error)
        }
    }

    func updateTamgu(_ first: String, _ second: String) async throws {
        guard let me = profile else { throw AppError.message("로그인이 필요해요.") }
        try await Supa.updateTamgu(first, second, userId: me.id)
        profile?.tamgu1 = first.trimmingCharacters(in: .whitespaces)
        profile?.tamgu2 = second.trimmingCharacters(in: .whitespaces)
        TamguNames.apply(profile)
    }

    func reload() async {
        errorText = nil
        do {
            async let posts = Supa.posts()
            async let exams = Supa.exams()
            async let stats = Supa.allExamStats()
            self.posts = try await posts
            self.exams = try await exams
            self.examStats = try await stats
        } catch {
            // 칼럼은 비회원이 못 읽는다. 그건 오류가 아니라 정상이다.
            errorText = friendly(error)
        }

        if loggedIn {
            submissions = (try? await Supa.mySubmissions()) ?? []
            readPosts = (try? await Supa.readPostIds()) ?? []
            readExams = (try? await Supa.readExamIds()) ?? []
        } else {
            submissions = []
            readPosts = []
            readExams = []
        }
    }

    /// 아직 안 읽은 글인지. 비회원에게는 표시하지 않는다.
    /// 내가 쓴 글은 안 읽음으로 두지 않는다.
    func isUnread(_ post: Post) -> Bool {
        guard loggedIn else { return false }
        if post.authorId == profile?.id { return false }
        return !readPosts.contains(post.id)
    }

    func isUnread(_ exam: Exam) -> Bool {
        guard loggedIn else { return false }
        if exam.authorId == profile?.id { return false }
        return !readExams.contains(exam.id)
    }

    // ── 로그인 ──────────────────────────────────────────

    func signIn(username: String, password: String) async throws {
        _ = try await Supa.client.auth.signIn(
            email: Supa.email(for: username),
            password: Supa.password(password))
        await refreshSession()
        await reload()
    }

    func signUp(username: String, password: String) async throws {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { throw AppError.message("아이디를 적어주세요.") }
        guard password.count >= 6 else { throw AppError.message("비밀번호는 6자 이상이어야 해요.") }

        _ = try await Supa.client.auth.signUp(
            email: Supa.email(for: name),
            password: Supa.password(password),
            data: ["username": .string(name)])
        // 가입하면 바로 로그인된다. 프로필은 서버 트리거가 만든다.
        try? await Task.sleep(nanoseconds: 400_000_000)
        await refreshSession()
        await reload()
    }

    func signOut() async {
        try? await Supa.client.auth.signOut()
        profile = nil
        submissions = []
        examRecords = []
        examCategories = []
        TamguNames.apply(nil)
        await reload()
    }

    // ── 제출 ────────────────────────────────────────────

    func submit(exam: Exam, answers: [String: JSONValue]) async throws -> Submission {
        guard let me = profile else { throw AppError.message("로그인이 필요해요.") }
        let sub = try await Supa.submit(
            examId: exam.id, student: me.username, studentId: me.id, answers: answers)
        submissions.insert(sub, at: 0)
        // 정답률은 서버가 다시 계산해준다
        examStats = (try? await Supa.allExamStats()) ?? examStats
        return sub
    }

    /// 비회원 제출. 기록은 안 남지만 정답률에는 들어간다.
    func submitAsGuest(exam: Exam, answers: [String: JSONValue]) async throws {
        try await Supa.submitGuest(examId: exam.id, answers: answers)
        examStats = (try? await Supa.allExamStats()) ?? examStats
    }

    func markRead(post: Post) async {
        guard let me = profile else { return }
        try? await Supa.markRead(postId: post.id, userId: me.id)
        readPosts.insert(post.id)
    }

    func markRead(exam: Exam) async {
        guard let me = profile else { return }
        try? await Supa.markRead(examId: exam.id, userId: me.id)
        readExams.insert(exam.id)
    }

    // ── 계정 ────────────────────────────────────────────

    func changePassword(_ new: String) async throws {
        guard new.count >= 6 else { throw AppError.message("비밀번호는 6자 이상이어야 해요.") }
        try await Supa.changePassword(new)
    }

    func updateKakaoId(_ value: String) async throws {
        guard let me = profile else { throw AppError.message("로그인이 필요해요.") }
        try await Supa.updateKakaoId(value, userId: me.id)
        profile?.kakaoId = value.trimmingCharacters(in: .whitespaces)
    }

    /// 탈퇴. 되돌릴 수 없다.
    func deleteMyAccount() async throws {
        try await Supa.deleteMyAccount()
        await signOut()
    }

    private func friendly(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.contains("Invalid login credentials") { return "아이디나 비밀번호가 맞지 않아요." }
        if raw.contains("already registered") { return "이미 있는 아이디예요." }
        if raw.contains("offline") || raw.contains("Internet") { return "인터넷에 연결되어 있는지 확인해 주세요." }
        return raw
    }

    func message(for error: Error) -> String { friendly(error) }
}
