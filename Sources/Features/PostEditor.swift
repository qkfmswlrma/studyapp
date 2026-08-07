import SwiftUI

// ─────────────────────────────────────────────────────────
// 칼럼과 공지 쓰기
//
// 칼럼과 공지는 같은 표를 쓴다. category 가 notice 인 것이 공지다.
// 글번호는 서버 트리거가 붙이므로 앱이 만들지 않는다.
//
// **본문은 글만 받는다.** 사이트 편집기는 굵게, 색, 사진, 수식 칩까지 넣는데
// 그걸 앱에서 다시 만들면 저장 모양이 어긋나기 쉽다. 수식이 든 글은 사이트에서 쓴다.
// 여기서 쓴 글은 사이트에서도 그대로 읽힌다. 줄바꿈만 <br> 로 바꿔 넣는다.
// ─────────────────────────────────────────────────────────

struct PostEditorSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let post: Post?
    let kind: PostKind

    @State private var title = ""
    @State private var body_ = ""
    @State private var category: PostCategory = .elem
    @State private var isDraft = false
    @State private var isRule = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        GlassCard(padding: 18) {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("제목", text: $title)
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(12)
                                    .background(Theme.hairline,
                                                in: RoundedRectangle(cornerRadius: 11))

                                if kind == .column {
                                    Picker("분류", selection: $category) {
                                        Text("초등").tag(PostCategory.elem)
                                        Text("중학").tag(PostCategory.mid)
                                        Text("고등").tag(PostCategory.high)
                                    }
                                    .pickerStyle(.segmented)
                                } else {
                                    Toggle("채팅방 규칙으로 두기", isOn: $isRule)
                                        .font(.system(size: 14, weight: .bold))
                                        .tint(Theme.purple)
                                    Text("규칙 글은 하나뿐이라 목록 맨 위로 올라와요")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.t3)
                                }

                                Toggle("임시 저장", isOn: $isDraft)
                                    .font(.system(size: 14, weight: .bold))
                                    .tint(Theme.purple)
                                if isDraft {
                                    Text("임시 저장한 글은 목록에 안 보여요")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.t3)
                                }
                            }
                        }

                        GlassCard(padding: 18) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("본문")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(Theme.t3)
                                TextEditor(text: $body_)
                                    .font(.system(size: 15))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 260)
                                    .padding(8)
                                    .background(Theme.hairline,
                                                in: RoundedRectangle(cornerRadius: 11))
                                Text("수식이나 사진이 들어가는 글은 사이트에서 써주세요")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.t3)
                            }
                        }

                        if let error {
                            Text(error)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Theme.red)
                        }

                        Button(busy ? "저장 중…" : "저장하기") { Task { await save() } }
                            .buttonStyle(BrandButtonStyle())
                            .disabled(busy)
                            .opacity(busy ? 0.6 : 1)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(post == nil
                             ? (kind == .notice ? "공지 쓰기" : "칼럼 쓰기")
                             : "글 고치기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }.foregroundStyle(Theme.t2)
                }
            }
        }
        .onAppear(perform: fill)
    }

    private func fill() {
        guard let p = post else {
            category = kind == .notice ? .notice : .elem
            return
        }
        title = p.title
        body_ = PostEditorSheet.toPlain(p.body)
        category = p.category
        isDraft = p.isDraft
        isRule = p.isRule
    }

    private func save() async {
        error = nil
        guard let me = store.profile else { return }
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { error = "제목을 적어주세요."; return }

        let category = kind == .notice ? PostCategory.notice : self.category

        busy = true
        defer { busy = false }
        do {
            if let p = post {
                try await Supa.updatePost(id: p.id, PostPatch(
                    title: name, body: PostEditorSheet.toHTML(body_),
                    category: category.rawValue,
                    is_draft: isDraft, is_rule: kind == .notice ? isRule : false))
                try? await Supa.log(action: "글 수정", target: name,
                                    actor: me.username, actorId: me.id)
            } else {
                try await Supa.savePost(PostInput(
                    title: name, body: PostEditorSheet.toHTML(body_),
                    author: me.username, author_id: me.id,
                    category: category.rawValue,
                    is_draft: isDraft, is_rule: kind == .notice ? isRule : false))
                try? await Supa.log(action: kind == .notice ? "공지 작성" : "칼럼 작성",
                                    target: name, actor: me.username, actorId: me.id)
            }
            await store.reload()
            dismiss()
        } catch {
            self.error = store.message(for: error)
        }
    }

    /// 사이트는 본문을 HTML 그대로 그린다. 줄바꿈을 <br> 로 바꿔야 줄이 나뉜다.
    static func toHTML(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return escaped.replacingOccurrences(of: "\n", with: "<br>")
    }

    /// 고칠 때는 도로 글로 푼다
    static func toPlain(_ html: String) -> String {
        HTMLBodyView.plain(html)
    }
}
