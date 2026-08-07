import SwiftUI

// ─────────────────────────────────────────────────────────
// 홈
// ─────────────────────────────────────────────────────────

struct HomeScreen: View {
    @EnvironmentObject var store: Store
    @Binding var authOpen: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.loggedIn
                                     ? "\(store.profile?.username ?? "")님, 안녕하세요"
                                     : "안녕하세요")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(Theme.t1)
                                Text(store.loggedIn
                                     ? "오늘도 한 문제 풀어볼까요"
                                     : "로그인하면 칼럼과 내 기록을 볼 수 있어요")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.t2)
                            }
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 10) {
                            shortcut("공지사항", "\(store.notices.count)개의 글",
                                     "megaphone.fill", Theme.pink)
                            shortcut("칼럼", store.loggedIn
                                     ? "\(store.columns(nil).count)개의 글" : "회원만 볼 수 있어요",
                                     "book.fill", Theme.purple)
                            shortcut("시험", "\(store.exams.count)개의 시험",
                                     "list.clipboard.fill", Theme.blue)
                        }
                        .padding(.horizontal, 20)

                        if !store.notices.isEmpty {
                            sectionTitle("최근 공지")
                            ForEach(store.notices.prefix(3)) { post in
                                NavigationLink {
                                    PostDetailScreen(post: post)
                                } label: {
                                    PostRow(post: post)
                                }
                                .buttonStyle(PressableCardStyle())
                                .padding(.horizontal, 20)
                            }
                        }

                        if let err = store.errorText {
                            Text(err)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.t3)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .refreshable { await store.reload() }
                .floatingHeader("수학질문방") { AccountButton(authOpen: $authOpen) }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 22)
            .padding(.top, 6)
    }

    private func shortcut(_ title: String, _ sub: String,
                          _ icon: String, _ color: Color) -> some View {
        GlassCard(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(color, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .heavy))
                        .foregroundStyle(Theme.t1)
                    Text(sub)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                }
                Spacer()
            }
        }
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
    @State private var category: PostCategory?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()

                if kind == .column && !store.loggedIn {
                    // 비회원에게 "글이 0개" 처럼 보이면 안 된다. 자물쇠 안내를 띄운다.
                    LockedNote()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
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
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .refreshable { await store.reload() }
                }
            }
            .floatingHeader(kind.title) { EmptyView() }
            .navigationDestination(for: Post.self) { PostDetailScreen(post: $0) }
        }
        // 화면을 찍을 때만 쓴다. 인자가 없으면 아무 일도 하지 않는다.
        .task {
            guard kind == .notice, Launch.open == "post",
                  let first = items.first else { return }
            path.append(first)
        }
    }

    private var items: [Post] {
        kind == .notice ? store.notices : store.columns(category)
    }

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            chip("전체", nil)
            chip("초등", .elem)
            chip("중학", .mid)
            chip("고등", .high)
        }
    }

    private func chip(_ label: String, _ value: PostCategory?) -> some View {
        let on = category == value
        return Button(label) { category = value }
            .font(.system(size: 13.5, weight: .bold))
            .foregroundStyle(on ? .white : Theme.t2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                if on { Capsule().fill(Theme.brand) }
                else { Capsule().fill(.ultraThinMaterial) }
            }
    }
}

struct PostRow: View {
    @EnvironmentObject var store: Store
    let post: Post

    var body: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    if post.isRule {
                        Text("규칙")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Theme.brand, in: RoundedRectangle(cornerRadius: 7))
                    }
                    Text(post.title)
                        .font(.system(size: 15.5, weight: .heavy))
                        .foregroundStyle(Theme.t1)
                        .multilineTextAlignment(.leading)
                    // 아직 안 읽은 글에 붙는 점
                    if store.isUnread(post) {
                        Circle().fill(Theme.red).frame(width: 7, height: 7)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 6) {
                    Text(post.author.isEmpty ? "관리자" : post.author)
                    if let date = post.createdAt {
                        Text("·")
                        Text(date, format: .dateTime.year().month().day())
                    }
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.t3)
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
    @State private var text: AttributedString?
    @State private var images: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let text {
                Text(text)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Theme.t1)
                    .textSelection(.enabled)
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
        for (entity, char) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"),
                               ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
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
