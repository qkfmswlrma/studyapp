import SwiftUI
import SwiftMath

/// 수식 한 덩이. KaTeX 대신 SwiftMath 가 네이티브로 그린다.
struct MathLabel: UIViewRepresentable {
    let latex: String
    var fontSize: CGFloat = 16
    var display = false
    var color: UIColor = UIColor(Theme.t1)

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.contentInsets = .zero
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    func updateUIView(_ label: MTMathUILabel, context: Context) {
        label.latex = latex
        label.fontSize = fontSize
        label.textColor = color
        label.labelMode = display ? .display : .text
        label.textAlignment = display ? .center : .left
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MTMathUILabel, context: Context) -> CGSize {
        uiView.latex = latex
        uiView.fontSize = fontSize
        uiView.labelMode = display ? .display : .text
        let size = uiView.sizeThatFits(CGSize(width: proposal.width ?? .greatestFiniteMagnitude,
                                              height: .greatestFiniteMagnitude))
        return CGSize(width: min(size.width, proposal.width ?? size.width), height: size.height)
    }
}

/// 글과 수식이 한 줄 안에서 섞이고, 넘치면 다음 줄로 넘어간다.
/// 문장 중간에 수식이 들어가는 문제가 많아서 줄바꿈이 자연스러워야 한다.
struct FlowLayout: Layout {
    var spacing: CGFloat = 3
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .greatestFiniteMagnitude ? x : maxWidth,
                      height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            // 같은 줄 안에서 아래쪽을 맞춘다. 수식이 글보다 크기 때문
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// 문제 본문. 글 조각과 수식 조각이 섞인 줄을 그린다.
/// boxstart 와 boxend 사이는 조건 박스 안에 넣는다.
/// 표시가 없는 예전 문제는 그대로 흐른다.
struct QuestionBodyView: View {
    let body_: [BodyBlock]
    var fontSize: CGFloat = 16

    init(_ blocks: [BodyBlock], fontSize: CGFloat = 16) {
        self.body_ = blocks
        self.fontSize = fontSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                if group.boxed {
                    lines(group.blocks)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.t2.opacity(0.45), lineWidth: 1.5))
                } else {
                    lines(group.blocks)
                }
            }
        }
    }

    @ViewBuilder
    private func lines(_ blocks: [BodyBlock]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(split(blocks).enumerated()), id: \.offset) { _, line in
                FlowLayout {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, item in
                        switch item {
                        case .word(let w):
                            Text(w)
                                .font(.system(size: fontSize))
                                .foregroundStyle(Theme.t1)
                        case .math(let latex):
                            MathLabel(latex: latex, fontSize: fontSize)
                        }
                    }
                }
            }
        }
    }

    // ── 조각 나누기 ─────────────────────────────────────

    private enum Item { case word(String), math(String) }
    private struct Group { var boxed: Bool; var blocks: [BodyBlock] }

    private var groups: [Group] {
        var out: [Group] = []
        var current = Group(boxed: false, blocks: [])
        for b in body_ {
            switch b {
            case .boxStart:
                if !current.blocks.isEmpty { out.append(current) }
                current = Group(boxed: true, blocks: [])
            case .boxEnd:
                if !current.blocks.isEmpty { out.append(current) }
                current = Group(boxed: false, blocks: [])
            default:
                current.blocks.append(b)
            }
        }
        if !current.blocks.isEmpty { out.append(current) }
        return out
    }

    /// 줄바꿈(\n)에서 줄을 끊고, 줄 안에서는 낱말과 수식으로 쪼갠다.
    /// 낱말 단위여야 줄 끝에서 자연스럽게 넘어간다.
    private func split(_ blocks: [BodyBlock]) -> [[Item]] {
        var lines: [[Item]] = [[]]
        for b in blocks {
            switch b {
            case .text(let raw):
                let parts = raw.components(separatedBy: "\n")
                for (i, part) in parts.enumerated() {
                    if i > 0 { lines.append([]) }
                    for word in part.split(separator: " ", omittingEmptySubsequences: true) {
                        lines[lines.count - 1].append(.word(String(word)))
                    }
                }
            case .math(let latex):
                lines[lines.count - 1].append(.math(latex))
            case .boxStart, .boxEnd:
                break
            }
        }
        return lines.filter { !$0.isEmpty }
    }
}

/// 옛 문제는 body 대신 latex 와 text 를 쓴다. 둘 다 받아준다.
struct QuestionBodyOrLegacy: View {
    let question: Question

    var body: some View {
        if !question.body.isEmpty {
            QuestionBodyView(question.body)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if let latex = question.latex, !latex.isEmpty {
                    MathLabel(latex: latex, fontSize: 18, display: true)
                        .frame(maxWidth: .infinity)
                }
                if let text = question.text, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.t1)
                }
            }
        }
    }
}
