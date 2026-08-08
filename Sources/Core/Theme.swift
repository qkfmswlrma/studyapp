import SwiftUI

/// 색과 짜임새는 디자인 시안(교육 플랫폼 iOS 앱 디자인)에서 가져왔다.
///
/// 다만 **유리는 시안대로 하지 않는다.** 시안은 카드도 탭 막대도 검색칸도
/// 전부 `backdrop-filter: blur()` 를 걸었는데, 그건 뒤를 흐리게만 하는 서리유리다.
/// 리퀴드 글래스는 뒤에 있는 것을 굴절시키고 가장자리에서 빛을 휜다.
/// 굴절시킬 내용이 있어야 유리로 보이므로, 읽을 것은 또렷한 판에 두고
/// 유리는 그 위에 떠 있는 것에만 쓴다. 아래 GlassCard 설명을 볼 것.
enum Theme {

    // ── 글자 ────────────────────────────────────────────
    // 유리 위 글자는 고정색을 쓰면 배경에 따라 안 읽힌다.
    // 본문은 .primary / .secondary 를 쓰고, 여기 색은 강조에만 쓴다.
    static let t1 = Color(light: 0x1C1230, dark: 0xEFE9FB)
    static let t2 = Color(light: 0x6B5C8C, dark: 0xB4A8D0)
    static let t3 = Color(light: 0x8B7BB0, dark: 0x8B80A8)

    // ── 강조색 ──────────────────────────────────────────
    static let purple = Color(hex: 0x6D3BF5)
    static let pink = Color(hex: 0xFF64C8)
    static let green = Color(hex: 0x12A594)
    static let red = Color(light: 0xFF3B6B, dark: 0xFF6B8F)
    static let blue = Color(hex: 0x6C8BFF)

    /// 시안의 히어로 카드에 쓰인 그라데이션.
    /// 가장 중요한 것에만 쓴다. 이건 유리가 아니라 꽉 찬 색이다.
    static let brand = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x8B5CF6), location: 0),
            .init(color: Color(hex: 0x6D3BF5), location: 0.55),
            .init(color: Color(hex: 0x4C1D95), location: 1),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    /// 단추와 작은 조작 요소에 쓰는 채움.
    /// 히어로 카드처럼 크게 깔 때는 3단이 좋지만, 작은 단추에 그대로 쓰면
    /// 한 단추 안에서 색이 크게 변해 번들거려 보인다. 두 단만 쓴다.
    static let buttonFill = LinearGradient(
        colors: [Color(hex: 0x8B5CF6), Color(hex: 0x6D3BF5)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let radius: CGFloat = 24

    /// 내용 카드의 바닥. 유리가 아니라 판이다.
    /// 아주 살짝만 비쳐서 뒤 색이 배어 나오되 글은 또렷하게 읽힌다.
    /// 하얗게 꽉 채우면 배경의 보라가 하나도 안 배어 나와 카드가 종잇장처럼 뜬다.
    /// 조금 비쳐야 시안처럼 배경 위에 얹힌 판으로 보인다.
    static let surface = Color(light: 0xFFFFFF, dark: 0x241B3C).opacity(0.72)
    static let hairline = Color(light: 0x6D3BF5, dark: 0xFFFFFF).opacity(0.10)

    /// 태그 알약. 시안의 rgba(109,59,245,0.12) 자리다.
    static let tagBackground = Color(light: 0x6D3BF5, dark: 0xB79BFF).opacity(0.14)

    /// 카드가 떠 보이게 하는 그림자색. 검정이 아니라 보라를 깐다.
    static let castShadow = Color(hex: 0x461996)

    static func rateColor(_ rate: Double) -> Color {
        switch rate {
        case ..<0.3: return red
        case ..<0.6: return Color(hex: 0xF5A623)
        default:     return green
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}

// ─────────────────────────────────────────────────────────
// 배경
// ─────────────────────────────────────────────────────────

/// 유리는 뒤에 볼 게 있어야 유리로 보인다.
/// 단색 위에 올리면 그냥 반투명한 회색 판이다.
/// 그래서 색 덩어리를 크게 풀어 깔고, 그 위에 유리를 얹는다.
///
/// 시안의 배경을 그대로 옮겼다. 연한 라벤더 바탕에 보라 덩어리가 왼쪽 위,
/// 분홍이 오른쪽 위, 진보라가 아래 가운데다. 색을 세 군데로만 몰아서
/// 무지개가 되지 않게 한다. 시안이 차분해 보이는 이유가 이것이다.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: base.0, location: 0),
                    .init(color: base.1, location: 0.55),
                    .init(color: base.2, location: 1),
                ],
                startPoint: .top, endPoint: .bottom)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                // 시안의 radial-gradient 세 개와 같은 자리, 같은 순서
                blob(blobColors.0, size: w * 1.15, alpha: scheme == .dark ? 0.50 : 0.60)
                    .position(x: w * 0.15, y: h * 0.02)
                blob(blobColors.1, size: w * 1.00, alpha: scheme == .dark ? 0.30 : 0.52)
                    .position(x: w * 0.95, y: h * 0.19)
                blob(blobColors.2, size: w * 1.30, alpha: scheme == .dark ? 0.52 : 0.46)
                    .position(x: w * 0.50, y: h * 1.02)
            }
        }
        .ignoresSafeArea()
    }

    private var base: (Color, Color, Color) {
        scheme == .dark
        ? (Color(hex: 0x150E26), Color(hex: 0x1B1233), Color(hex: 0x221741))
        : (Color(hex: 0xF6F2FF), Color(hex: 0xECE4FF), Color(hex: 0xE2D6FF))
    }

    private var blobColors: (Color, Color, Color) {
        scheme == .dark
        ? (Color(hex: 0x7C4DFF), Color(hex: 0xFF6FD0), Color(hex: 0x5B21B6))
        : (Color(hex: 0x9D6AFF), Color(hex: 0xFFA4E8), Color(hex: 0x6D3BF5))
    }

    /// 시안의 `radial-gradient(… , rgba(색,0.45), rgba(색,0) 70%)` 그대로.
    ///
    /// 원을 칠하고 흐리게 하는 방법도 있지만 그러면 색이 뭉개져 밋밋한 한 덩어리가 된다.
    /// 가운데가 진하고 가장자리로 갈수록 사라지는 그라데이션이라야 색 자리가 산다.
    /// 유리가 굴절시킬 것이 바로 이 색 차이다.
    private func blob(_ color: Color, size: CGFloat, alpha: Double) -> some View {
        Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: color.opacity(alpha), location: 0),
                    .init(color: color.opacity(alpha * 0.45), location: 0.45),
                    .init(color: color.opacity(0), location: 1),
                ],
                center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
    }
}

// ─────────────────────────────────────────────────────────
// 유리
// ─────────────────────────────────────────────────────────

/// 유리 테두리.
///
/// 진짜 유리는 위쪽 모서리에서 빛이 튕겨 밝게 빛나고 아래쪽은 어둡다.
/// 이 한 줄이 있고 없고가 "유리"와 "반투명한 판"을 가른다.
struct GlassStroke: View {
    var radius: CGFloat = Theme.radius
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // 왼쪽 위를 밝게, 오른쪽 아래를 어둡게 그리면 입체가 나긴 한다.
        // 그런데 그건 손으로 그린 입체다. 빛이 실제로 도는 게 아니라 칠해둔 것이라
        // 각도를 바꿔도 그대로 있어서 금세 어색해진다.
        // 여기서는 아주 옅은 실선 하나로만 가장자리를 잡는다.
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(.white.opacity(scheme == .dark ? 0.12 : 0.45), lineWidth: 0.8)
    }
}

extension View {
    /// 어떤 것이든 유리판 위에 올린다.
    ///
    /// iOS 26 부터는 **리퀴드 글래스**를 쓴다. Material 과 다른 점은,
    /// 흐리게만 하는 게 아니라 뒤에 있는 것을 실제로 굴절시키고 가장자리에서 빛을 휜다.
    /// 화면이 움직이면 유리도 같이 반응한다.
    ///
    /// iOS 25 이하에서는 Material 로 떨어진다. 옛 아이폰에서도 앱은 그대로 돌아간다.
    ///
    /// - `material`: 리퀴드 글래스를 못 쓸 때 대신 쓸 유리 두께.
    /// - `interactive`: 눌리는 것인지. 리퀴드 글래스는 누르면 유리가 눌리듯 반응한다.
    /// - `frosted`: 뒤를 가리는 서리유리로 할지.
    ///   기본은 **맑은 유리**다. 뒤가 그대로 비치고 가장자리에서 휘어야 유리로 보인다.
    ///   서리유리(`.regular`)로 하면 허옇게 뜬 판이 된다.
    ///   글이 빽빽해서 뒤가 비치면 읽기 힘든 곳에만 서리유리를 쓴다.
    @ViewBuilder
    func glass(radius: CGFloat = Theme.radius,
               material: Material = .ultraThinMaterial,
               shadow: Bool = true,
               interactive: Bool = false,
               frosted: Bool = false,
               tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(
                    liquid(interactive: interactive, frosted: frosted, tint: tint),
                    in: shape)
                // 리퀴드 글래스는 테두리와 그림자를 스스로 그린다.
                // 여기서 또 그으면 두 겹이 되어 지저분해진다.
                .shadow(color: Color(hex: 0x4B2A7A).opacity(shadow ? 0.10 : 0), radius: 18, y: 9)
        } else {
            legacyGlass(shape: shape, material: material, shadow: shadow, radius: radius)
        }
        #else
        legacyGlass(shape: shape, material: material, shadow: shadow, radius: radius)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private func liquid(interactive: Bool, frosted: Bool, tint: Color?) -> Glass {
        var g: Glass = frosted ? .regular : .clear
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
    #endif

    /// iOS 25 이하에서 쓰는 유리. Material 에 빛 방향을 손으로 얹는다.
    private func legacyGlass(shape: RoundedRectangle, material: Material,
                             shadow: Bool, radius: CGFloat) -> some View {
        self
            .background(material, in: shape)
            .overlay(GlassStroke(radius: radius))
            .clipShape(shape)
            // 유리는 떠 있어야 한다. 그림자가 없으면 배경에 붙어 보인다.
            // 두 겹으로 준다. 좁고 진한 것과 넓고 옅은 것.
            .shadow(color: .black.opacity(shadow ? 0.06 : 0), radius: 3, y: 1)
            .shadow(color: Color(hex: 0x4B2A7A).opacity(shadow ? 0.10 : 0), radius: 20, y: 10)
    }
}

/// 유리 여러 개를 한 덩어리로 묶는다.
///
/// 리퀴드 글래스는 가까이 붙은 유리끼리 서로 녹아 붙는다. 물방울이 합쳐지듯이.
/// 이 안에 넣지 않으면 각자 따로 놀아서 그냥 유리판 여러 장이 된다.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// 내용 카드.
///
/// **유리가 아니다.** 애플은 화면을 두 층으로 나눈다.
///   내용 층 — 실제 읽을 것. 또렷해야 한다
///   유리 층 — 그 위에 떠 있는 탐색과 조작 요소. 아래 내용을 굴절시킨다
///
/// 목록 카드까지 유리로 만들면 유리가 굴절시킬 내용이 없어져서 허옇게 뜬 판이 겹친다.
/// 애플 문서도 "화면에 동시에 올리는 유리 수를 제한하라" 고 못박는다.
/// 그래서 카드는 안 비치는 판으로 두고, 유리는 제목줄과 탭 막대에만 쓴다.
///
/// 이름은 예전 그대로 둔다. 부르는 곳이 많아서 바꾸면 다 고쳐야 한다.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = Theme.radius
    var material: Material = .ultraThinMaterial
    var frosted: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5))
            // 시안의 0 14px 30px rgba(70,25,150,0.12)
            .shadow(color: Theme.castShadow.opacity(0.12), radius: 15, y: 7)
    }
}

// ─────────────────────────────────────────────────────────
// 시안에서 되풀이되는 조각들
// ─────────────────────────────────────────────────────────

/// 화면 제목. 시안은 제목줄을 따로 띄우지 않고 내용 맨 위에 크게 적는다.
///
/// 떠 있는 제목줄을 없앤 이유가 있다. 유리는 화면에 한두 개만 있어야 한다.
/// 탭 막대가 이미 유리라서, 제목줄까지 유리로 띄우면 유리가 유리를 굴절시킨다.
struct ScreenTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy))
            .tracking(-0.8)
            .foregroundStyle(Theme.t1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 분류를 나타내는 작은 알약. 시안에서 글 카드마다 붙는다.
struct TagPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Theme.purple)
            .padding(.horizontal, 9)
            .padding(.vertical, 3.5)
            .background(Theme.tagBackground, in: Capsule())
    }
}

/// 아직 안 읽은 것에 붙는 점
struct UnreadDot: View {
    var body: some View {
        Circle().fill(Theme.red).frame(width: 7, height: 7)
    }
}

// ─────────────────────────────────────────────────────────
// 단추
// ─────────────────────────────────────────────────────────

/// 주요 단추. 색을 칠하되 위쪽에 빛 반사를 얹어 유리처럼 보이게 한다.
struct BrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            // 위쪽에 흰 그라데이션을 덧칠하지 않는다.
            // 유광 단추는 2010년대 초반 수법이고, 유리처럼 보이려고 칠한 그림일 뿐이다.
            // 깊이는 색과 그림자로 낸다.
            .background(Theme.buttonFill, in: Capsule())
            .shadow(color: Theme.purple.opacity(0.28), radius: 14, y: 6)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

/// 유리 단추. 색 없이 뒤가 비친다.
/// iOS 26 에서는 누르면 유리가 실제로 눌리듯 일그러진다(`interactive`).
struct GlassButtonStyle: ButtonStyle {
    var radius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .glass(radius: radius, material: .thinMaterial, interactive: true)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

/// 카드를 눌렀을 때 살짝 들어가는 느낌. 목록에서 쓴다.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75),
                       value: configuration.isPressed)
    }
}

struct EmptyNote: View {
    let text: String
    var body: some View {
        GlassCard {
            Text(text)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
    }
}
