import SwiftUI

// ─────────────────────────────────────────────────────────
// 수식 입력
//
// 사이트는 MathLive 를 쓴다. 수식 모양 그대로 편집되는 물건인데
// 웹 부품이라 앱에 그대로 옮길 수 없다. WKWebView 로 감싸는 방법도 있지만
// 그러면 앱 안에 웹을 다시 들이게 되고, 인터넷이 끊기면 출제가 막힌다.
//
// 그래서 여기서는 **LaTeX 를 직접 적고 그린 모양을 바로 보여주는** 쪽으로 간다.
// 자주 쓰는 기호는 단추로 넣어서 손으로 다 치지 않아도 된다.
// 그리는 것은 SwiftMath 라 화면에 보이는 모양이 실제로 학생이 볼 모양과 같다.
// ─────────────────────────────────────────────────────────

struct MathInputSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initial: String
    let onDone: (String) -> Void

    @State private var latex = ""

    /// 넣을 자리를 나타내는 표시. 단추를 누르면 커서 대신 이걸 남긴다.
    private static let hole = "□"

    /// 튜플에는 키패스를 못 걸어서 ForEach 가 못 쓴다. 구조체로 둔다.
    struct PaletteItem: Identifiable, Hashable {
        let label: String
        let snippet: String
        var id: String { snippet }
    }
    struct PaletteGroup: Identifiable, Hashable {
        let group: String
        let items: [PaletteItem]
        var id: String { group }
    }

    private let palette: [PaletteGroup] = [
        .init(group: "자주 쓰는 것", items: [
            .init(label: "분수", snippet: "\\frac{□}{□}"),
            .init(label: "제곱", snippet: "□^{□}"),
            .init(label: "아래첨자", snippet: "□_{□}"),
            .init(label: "루트", snippet: "\\sqrt{□}"),
            .init(label: "n제곱근", snippet: "\\sqrt[□]{□}"),
            .init(label: "절댓값", snippet: "\\left|□\\right|"),
        ]),
        .init(group: "수열과 극한", items: [
            .init(label: "시그마", snippet: "\\sum_{k=1}^{n}"),
            .init(label: "극한", snippet: "\\lim_{n \\to \\infty}"),
            .init(label: "적분", snippet: "\\int_{a}^{b}"),
            .init(label: "미분", snippet: "\\frac{d}{dx}"),
            .init(label: "무한대", snippet: "\\infty"),
        ]),
        .init(group: "기호", items: [
            .init(label: "×", snippet: "\\times"),
            .init(label: "÷", snippet: "\\div"),
            .init(label: "±", snippet: "\\pm"),
            .init(label: "≤", snippet: "\\le"),
            .init(label: "≥", snippet: "\\ge"),
            .init(label: "≠", snippet: "\\ne"),
            .init(label: "→", snippet: "\\to"),
            .init(label: "∈", snippet: "\\in"),
            .init(label: "∴", snippet: "\\therefore"),
        ]),
        .init(group: "그리스 문자", items: [
            .init(label: "α", snippet: "\\alpha"),
            .init(label: "β", snippet: "\\beta"),
            .init(label: "θ", snippet: "\\theta"),
            .init(label: "π", snippet: "\\pi"),
            .init(label: "Σ", snippet: "\\Sigma"),
            .init(label: "Δ", snippet: "\\Delta"),
        ]),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("이렇게 보여요")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(Theme.t3)
                                // 학생이 볼 모양과 같은 것으로 그린다
                                MathLabel(latex: latex, fontSize: 22, display: true)
                                    .frame(maxWidth: .infinity, minHeight: 54)
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LaTeX")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(Theme.t3)
                                TextEditor(text: $latex)
                                    .font(.system(size: 15, design: .monospaced))
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 90)
                                    .padding(8)
                                    .background(Theme.hairline,
                                                in: RoundedRectangle(cornerRadius: 11))
                                Text("□ 자리에 숫자나 글자를 넣으면 돼요")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.t3)
                            }
                        }

                        ForEach(palette) { section in
                            GlassCard(padding: 15) {
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(section.group)
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundStyle(Theme.t3)
                                    let columns = [GridItem(.adaptive(minimum: 74), spacing: 7)]
                                    LazyVGrid(columns: columns, spacing: 7) {
                                        ForEach(section.items) { item in
                                            Button(item.label) { insert(item.snippet) }
                                                .font(.system(size: 13.5, weight: .bold))
                                                .foregroundStyle(Theme.t1)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(Theme.surface.opacity(0.8),
                                                            in: RoundedRectangle(cornerRadius: 11))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("수식")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("그만두기") { dismiss() }.foregroundStyle(Theme.t2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("넣기") {
                        onDone(latex.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.purple)
                }
            }
        }
        .onAppear { latex = initial }
    }

    private func insert(_ snippet: String) {
        // 빈 자리가 있으면 거기를 채우고, 없으면 뒤에 잇는다.
        // 손으로 커서를 옮기지 않아도 분수 위아래를 차례로 채울 수 있다.
        if let range = latex.range(of: MathInputSheet.hole) {
            latex.replaceSubrange(range, with: snippet)
        } else {
            latex += snippet
        }
    }
}
