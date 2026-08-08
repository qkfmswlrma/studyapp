import SwiftUI

// ─────────────────────────────────────────────────────────
// 홈
// ─────────────────────────────────────────────────────────

/// 홈에서만 들어가는 화면. 탭을 차지할 만큼은 아니지만 어딘가에는 있어야 한다.
enum HomeRoute: Hashable {
    case notice
    case game
    case daily
}

struct HomeScreen: View {
    @EnvironmentObject var store: Store
    @Binding var authOpen: Bool
    @Binding var tab: Int
    @State private var path = NavigationPath()

    /// 히어로 자리에 올릴 오늘의 문제. 서버가 공개된 것만 내려준다.
    private var todayExam: Exam? { store.exams(of: .today).first }

    /// 가로로 훑는 새 글. 칼럼은 회원만 받아오므로 비회원에게는 공지만 남는다.
    private var feed: [Post] {
        (store.columns(nil) + store.notices)
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        greeting
                            .padding(.horizontal, 20)
                            .padding(.bottom, 18)

                        if let todayExam {
                            NavigationLink(value: HomeRoute.daily) {
                                TodayHeroCard(exam: todayExam,
                                              stat: store.examStats[todayExam.id],
                                              solved: store.mySubmission(examId: todayExam.id) != nil)
                            }
                            .buttonStyle(PressableCardStyle())
                            .padding(.horizontal, 20)
                        }

                        if !feed.isEmpty {
                            sectionHeader("새 글", more: "모두 보기") { tab = 1 }
                                .padding(.horizontal, 20)
                                .padding(.top, 26)
                                .padding(.bottom, 12)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 11) {
                                    ForEach(feed) { post in
                                        NavigationLink(value: post) {
                                            FeedCard(post: post, unread: store.isUnread(post))
                                        }
                                        .buttonStyle(PressableCardStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 2)
                            }
                        }

                        // 공지와 게임은 탭을 차지하지 않는다. 시안처럼 홈에서 들어간다.
                        HStack(spacing: 11) {
                            miniCard("공지사항",
                                     store.notices.contains(where: \.isRule) ? "규칙 고정됨"
                                                                             : "\(store.notices.count)개",
                                     dot: store.notices.contains { store.isUnread($0) },
                                     route: .notice)
                            miniCard("스피드 연산", "머리 식히기", dot: false, route: .game)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 26)

                        if !store.loggedIn {
                            Text("로그인하면 칼럼과 내 기록을 볼 수 있어요")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.t3)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 18)
                        }

                        if let err = store.errorText {
                            Text(err)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.t3)
                                .padding(.horizontal, 20)
                                .padding(.top, 14)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .refreshable { await store.reload() }
            }
            .navigationDestination(for: Post.self) { PostDetailScreen(post: $0) }
            .navigationDestination(for: Exam.self) { ExamEntryScreen(exam: $0) }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .notice: PostListScreen(kind: .notice, embedded: true)
                case .game:   GameScreen(embedded: true)
                case .daily:  DailyPuzzleScreen()
                }
            }
        }
        // 화면을 찍을 때만 쓴다. 인자가 없으면 아무 일도 하지 않는다.
        .task {
            switch Launch.open {
            case "notice": path.append(HomeRoute.notice)
            case "game":   path.append(HomeRoute.game)
            case "post":
                path.append(HomeRoute.notice)
                if let first = store.notices.first { path.append(first) }
            default: break
            }
        }
    }

    /// 시안의 "안녕하세요 / 민준님" 자리
    private var greeting: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.loggedIn ? "안녕하세요" : "수학질문방")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.t2)
                Text(store.loggedIn ? "\(store.profile?.username ?? "")님" : "안녕하세요")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.9)
                    .foregroundStyle(Theme.t1)
            }
            Spacer(minLength: 12)
            AccountButton(authOpen: $authOpen)
        }
    }

    private func sectionHeader(_ title: String, more: String,
                               tap: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 19, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Theme.t1)
            Spacer()
            Button(more, action: tap)
                .font(.system(size: 12.5, weight: .heavy))
                .foregroundStyle(Theme.purple)
        }
    }

    private func miniCard(_ title: String, _ sub: String,
                          dot: Bool, route: HomeRoute) -> some View {
        NavigationLink(value: route) {
            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15.5, weight: .heavy))
                            .tracking(-0.3)
                            .foregroundStyle(Theme.t1)
                        if dot { UnreadDot() }
                        Spacer(minLength: 0)
                    }
                    Text(sub)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                }
            }
        }
        .buttonStyle(PressableCardStyle())
    }
}

/// 오늘의 문제 히어로.
///
/// **여기만 유리가 아니다.** 화면에서 가장 먼저 눌러야 할 것은 꽉 찬 색으로 둔다.
/// 유리로 만들면 배경에 녹아들어 눈에 안 띈다. 시안도 이 카드만 색을 채웠다.
struct TodayHeroCard: View {
    let exam: Exam
    let stat: ExamStat?
    let solved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(.white).frame(width: 7, height: 7)
                Text(dateLabel)
                    .font(.system(size: 11.5, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.9))
            }

            // 위 줄에서 이미 "오늘의 문제"라고 했으므로 제목을 또 적지 않는다
            Text(solved ? "다시 볼 수 있어요" : "아직 안 풀었어요")
                .font(.system(size: 23, weight: .heavy))
                .tracking(-0.7)
                .foregroundStyle(.white)
                .padding(.top, 10)

            HStack {
                if let rate = stat?.rate {
                    Text("평균 정답률 \(Int(rate * 100))%")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }
                Spacer(minLength: 8)
                Text(solved ? "다시 보기" : "풀기")
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.2), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            }
            .padding(.top, 16)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // 색을 먼저 깔고 그 위에 빛 도는 원을 얹는다.
            // 원을 내용과 나란히 두면 원 크기만큼 카드가 키를 잡아 쓸데없이 높아진다.
            Theme.brand.overlay(alignment: .topTrailing) {
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 150, height: 150)
                    .offset(x: 34, y: -46)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.castShadow.opacity(0.32), radius: 24, y: 12)
    }

    private var dateLabel: String {
        guard let date = exam.publishAt ?? exam.createdAt else { return "오늘의 문제" }
        return "오늘의 문제 · " + date.formatted(.dateTime.month().day())
    }
}

/// 가로로 훑는 새 글 카드
struct FeedCard: View {
    let post: Post
    let unread: Bool

    var body: some View {
        GlassCard(padding: 15, radius: 24) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    TagPill(text: post.isRule ? "규칙" : post.category.label)
                    if unread { UnreadDot() }
                    Spacer(minLength: 0)
                }
                Text(post.title)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(-0.25)
                    .lineSpacing(2)
                    .foregroundStyle(Theme.t1)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.top, 9)
                Spacer(minLength: 6)
                Text(meta)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.t3)
            }
            .frame(width: 166, height: 92, alignment: .topLeading)
        }
    }

    private var meta: String {
        let who = post.author.isEmpty ? "관리자" : post.author
        guard let date = post.createdAt else { return who }
        return who + " · " + date.formatted(.dateTime.month().day())
    }
}

// ─────────────────────────────────────────────────────────
// 칼럼과 공지 목록
// ─────────────────────────────────────────────────────────

enum PostKind {
    case notice, column

    var title: String {
        switch self {
        case .notice: return "공지사항"
        case .column: return "칼럼"
        }
    }
}

struct PostListScreen: View {
    @EnvironmentObject var store: Store
    let kind: PostKind
    /// 홈에서 밀고 들어온 경우에는 이미 남의 탐색 더미 안이다.
    /// 그때 또 감싸면 더미가 겹쳐서 뒤로가기가 두 겹이 된다.
    var embedded = false

    @State private var category: PostCategory?
    @State private var path = NavigationPath()
    @State private var writing = false
    @State private var editing: Post?

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack(path: $path) { content }
                // 화면을 찍을 때만 쓴다. 인자가 없으면 아무 일도 하지 않는다.
                .task {
                    guard kind == .notice, Launch.open == "post",
                          let first = items.first else { return }
                    path.append(first)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            AppBackground()

            if kind == .column && !store.loggedIn {
                // 비회원에게 "글이 0개" 처럼 보이면 안 된다. 자물쇠 안내를 띄운다.
                LockedNote()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ScreenTitle(text: kind.title)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 2)

                        if kind == .column {
                            categoryPicker
                                .padding(.horizontal, 20)
                        }

                        if items.isEmpty {
                            EmptyNote(text: "아직 글이 없어요")
                                .padding(.horizontal, 20)
                        } else {
                            ForEach(items) { post in
                                NavigationLink(value: post) {
                                    PostRow(post: post)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 20)
                                .contextMenu {
                                    // 남이 쓴 글은 root 만 고친다. 서버 정책도 같다.
                                    if store.canEdit(post) {
                                        Button("고치기") { editing = post }
                                        Button("지우기", role: .destructive) {
                                            Task { await store.deletePost(post) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .refreshable { await store.reload() }
            }
        }
        // 홈에서 밀고 들어왔을 때는 홈이 이미 등록해뒀다. 두 번 걸지 않는다.
        .modifier(PostDestination(active: !embedded))
        .toolbar {
            if store.isAdmin {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { writing = true } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Theme.purple)
                    }
                }
            }
        }
        .sheet(isPresented: $writing) {
            PostEditorSheet(post: nil, kind: kind)
        }
        .sheet(item: $editing) { post in
            PostEditorSheet(post: post, kind: kind)
        }
    }

    private var items: [Post] {
        kind == .notice ? store.notices : store.columns(category)
    }

    /// 시안의 분류 고르개. 알약 네 개를 한 칸 안에 넣는다.
    private var categoryPicker: some View {
        HStack(spacing: 6) {
            chip("전체", nil)
            chip("초등", .elem)
            chip("중학", .mid)
            chip("고등", .high)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Theme.surface.opacity(0.5)))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5))
    }

    private func chip(_ label: String, _ value: PostCategory?) -> some View {
        let on = category == value
        // .snappy 는 iOS 17 부터라 쓰지 않는다. 내려받는 기준은 16 이다.
        return Button(label) { withAnimation(.easeOut(duration: 0.2)) { category = value } }
            .font(.system(size: 13.5, weight: .heavy))
            .foregroundStyle(on ? .white : Theme.t2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if on {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.brand)
                        .shadow(color: Theme.purple.opacity(0.3), radius: 9, y: 4)
                }
            }
    }
}

/// 글 상세로 가는 길을 등록한다.
/// 같은 더미에 두 번 걸면 어느 쪽이 이길지 알 수 없어서 한 번만 건다.
private struct PostDestination: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.navigationDestination(for: Post.self) { PostDetailScreen(post: $0) }
        } else {
            content
        }
    }
}

struct PostRow: View {
    @EnvironmentObject var store: Store
    let post: Post

    var body: some View {
        GlassCard(padding: 16, radius: 22) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    TagPill(text: post.isRule ? "규칙" : post.category.label)
                    // 아직 안 읽은 글에 붙는 점
                    if store.isUnread(post) { UnreadDot() }
                    Spacer(minLength: 0)
                }
                Text(post.title)
                    .font(.system(size: 16, weight: .bold))
                    .tracking(-0.25)
                    .lineSpacing(2)
                    .foregroundStyle(Theme.t1)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(post.author.isEmpty ? "관리자" : post.author)
                    if let date = post.createdAt {
                        Text("·")
                        Text(date, format: .dateTime.year().month().day())
                    }
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.t2)
            }
        }
    }
}

/// 칼럼은 회원 전용이다.
struct LockedNote: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Theme.brand, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text("칼럼은 회원만 볼 수 있어요")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Theme.t1)
            Text("로그인하면 바로 읽을 수 있어요")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.t2)
        }
        .padding(30)
    }
}

// ─────────────────────────────────────────────────────────
// 글 읽기
// ─────────────────────────────────────────────────────────

struct PostDetailScreen: View {
    @EnvironmentObject var store: Store
    let post: Post

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(post.title)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Theme.t1)
                        HStack(spacing: 6) {
                            Text(post.author.isEmpty ? "관리자" : post.author)
                            if let date = post.createdAt {
                                Text("·")
                                Text(date, format: .dateTime.year().month().day())
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                    }

                    GlassCard {
                        HTMLBodyView(html: post.body)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(post.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.markRead(post: post) }
    }
}

/// 글 본문은 편집기가 만든 HTML 이다.
/// 사진은 따로 뽑아서 아래에 붙인다. HTML 변환기에 맡기면 사진을 받아오는 동안 화면이 멈춘다.
struct HTMLBodyView: View {
    let html: String
    @State private var images: [URL] = []

    /// 수식이 든 글만 조각내어 그린다.
    /// 수식이 없는 글은 지금처럼 통째로 두는 쪽이 줄간격과 띄어쓰기가 자연스럽다.
    private var blocks: [BodyBlock]? {
        let parsed = HTMLBodyView.blocks(html)
        let hasMath = parsed.contains { block in
            if case .math = block { return true }
            return false
        }
        return hasMath ? parsed : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let blocks {
                QuestionBodyView(blocks, fontSize: 15.5)
            } else {
                Text(HTMLBodyView.plain(html))
                    .font(.system(size: 15.5))
                    .foregroundStyle(Theme.t1)
                    .textSelection(.enabled)
            }

            ForEach(images, id: \.self) { url in
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(height: 160)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .task { parse() }
    }

    private func parse() {
        images = HTMLBodyView.imageURLs(html)
    }

    // ── 수식 칩 ─────────────────────────────────────────
    //
    // 편집기는 수식을 이렇게 넣는다.
    //
    //     <span class="mchip" data-latex="x^2"> …KaTeX 가 만든 조각… </span>
    //
    // 안쪽 KaTeX 조각에는 같은 수식이 MathML 로도 글자로도 들어 있어서,
    // 태그만 벗기면 "x2x^2x2" 처럼 겹쳐 나온다. **안쪽은 통째로 버리고
    // data-latex 만 쓴다.** 사이트의 본문 파서도 칩 안으로는 들어가지 않는다.

    private static let chipOpen = try? NSRegularExpression(
        pattern: "<span[^>]*class=\"[^\"]*mchip[^\"]*\"[^>]*>",
        options: .caseInsensitive)

    static func blocks(_ html: String) -> [BodyBlock] {
        guard let re = chipOpen else { return [.text(plain(html))] }
        let ns = html as NSString
        var out: [BodyBlock] = []
        var cursor = 0

        for m in re.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            // 앞선 칩 안에 들어 있던 것은 이미 건너뛴 자리다
            guard m.range.location >= cursor else { continue }

            let before = plain(ns.substring(with: NSRange(
                location: cursor, length: m.range.location - cursor)))
            if !before.isEmpty { out.append(.text(before)) }

            out.append(.math(latexAttribute(ns.substring(with: m.range))))
            cursor = endOfSpan(ns, from: m.range.location + m.range.length)
        }

        if cursor < ns.length {
            let tail = plain(ns.substring(from: cursor))
            if !tail.isEmpty { out.append(.text(tail)) }
        }
        return out
    }

    /// 여는 `<span>` 에서 data-latex 값을 꺼낸다.
    private static func latexAttribute(_ tag: String) -> String {
        let ns = tag as NSString
        guard let re = try? NSRegularExpression(pattern: "data-latex=\"([^\"]*)\"",
                                                options: .caseInsensitive),
              let m = re.firstMatch(in: tag, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1
        else { return "" }
        return unescape(ns.substring(with: m.range(at: 1)))
    }

    /// 칩을 닫는 `</span>` 뒤의 자리. KaTeX 조각 안에 `<span>` 이 겹겹이 있어서
    /// 처음 만나는 닫는 태그를 쓰면 안 되고 깊이를 세야 한다.
    private static func endOfSpan(_ ns: NSString, from start: Int) -> Int {
        var depth = 1
        var i = start
        while i < ns.length && depth > 0 {
            let rest = NSRange(location: i, length: ns.length - i)
            let open = ns.range(of: "<span", options: .caseInsensitive, range: rest)
            let close = ns.range(of: "</span", options: .caseInsensitive, range: rest)
            if close.location == NSNotFound { return ns.length }

            if open.location != NSNotFound && open.location < close.location {
                depth += 1
                i = open.location + open.length
            } else {
                depth -= 1
                let after = NSRange(location: close.location,
                                    length: ns.length - close.location)
                let gt = ns.range(of: ">", range: after)
                i = gt.location == NSNotFound ? ns.length : gt.location + 1
            }
        }
        return i
    }

    /// 아주 단순한 태그 벗기기. 편집기가 내는 범위만 다룬다.
    static func plain(_ html: String) -> String {
        var s = html
        for (pattern, replacement) in [
            ("<br\\s*/?>", "\n"),
            ("</p>", "\n"),
            ("</div>", "\n"),
            ("<li>", "· "),
            ("</li>", "\n"),
        ] {
            s = s.replacingOccurrences(of: pattern, with: replacement,
                                       options: [.regularExpression, .caseInsensitive])
        }
        s = s.replacingOccurrences(of: "<[^>]+>", with: "",
                                   options: [.regularExpression])
        return unescape(s).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `&amp;` 같은 표기를 원래 글자로 되돌린다.
    /// data-latex 도 같은 식으로 적혀 있어서 수식에도 쓴다.
    static func unescape(_ text: String) -> String {
        var s = text
        for (entity, char) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"),
                               ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        return s
    }

    static func imageURLs(_ html: String) -> [URL] {
        guard let re = try? NSRegularExpression(
            pattern: "<img[^>]+src=[\"']([^\"']+)[\"']", options: .caseInsensitive)
        else { return [] }
        let ns = html as NSString
        return re.matches(in: html, range: NSRange(location: 0, length: ns.length))
            .compactMap { m in
                guard m.numberOfRanges > 1 else { return nil }
                return URL(string: ns.substring(with: m.range(at: 1)))
            }
    }
}
