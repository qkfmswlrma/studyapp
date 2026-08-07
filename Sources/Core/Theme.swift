import SwiftUI

/// 색은 사이트에서 그대로 가져왔다 (_source.html 5859~5864줄).
/// 유리 느낌은 웹처럼 흉내내지 않고 애플이 주는 Material 을 쓴다.
///
/// 웹의 backdrop-filter 는 뒤를 흐리게 하는 게 전부다.
/// Material 은 뒤에 깔린 색을 실시간으로 빨아들여서 글자 대비까지 알아서 맞춘다.
/// 그래서 밝은 배경 위에서는 살짝 어둡게, 어두운 배경 위에서는 살짝 밝게 스스로 변한다.
enum Theme {

    // ── 글자 ────────────────────────────────────────────
    // 유리 위 글자는 고정색을 쓰면 배경에 따라 안 읽힌다.
    // 본문은 .primary / .secondary 를 쓰고, 여기 색은 강조에만 쓴다.
    static let t1 = Color(light: 0x2C2347, dark: 0xEDE7FA)
    static let t2 = Color(light: 0x6F6391, dark: 0xB3A9CC)
    static let t3 = Color(light: 0x9A8FB8, dark: 0x8A81A6)

    // ── 강조색 ──────────────────────────────────────────
    static let purple = Color(hex: 0x9B6CFF)
    static let pink = Color(hex: 0xFF8FC8)
    static let green = Color(hex: 0x16A394)
    static let red = Color(light: 0xE5484D, dark: 0xFF6B70)
    static let blue = Color(hex: 0x7C9BFF)

    static let brand = LinearGradient(
        colors: [Color(hex: 0x9B6CFF), Color(hex: 0xFF8FC8)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let radius: CGFloat = 22

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
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(light: 0xF4E9FF, dark: 0x161226), location: 0),
                    .init(color: Color(light: 0xFDE9F4, dark: 0x1E1730), location: 0.46),
                    .init(color: Color(light: 0xE9EEFF, dark: 0x141726), location: 1),
                ],
                startPoint: .top, endPoint: .bottom)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                blob(Theme.purple, size: w * 1.05)
                    .position(x: w * 0.18, y: h * 0.12)
                blob(Theme.pink, size: w * 0.95)
                    .position(x: w * 0.92, y: h * 0.34)
                blob(Theme.blue, size: w * 1.1)
                    .position(x: w * 0.55, y: h * 0.86)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            // 밝은 화면에서는 은은하게, 어두운 화면에서는 더 죽인다
            .opacity(scheme == .dark ? 0.20 : 0.34)
            .blur(radius: size * 0.28)
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
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(scheme == .dark ? 0.34 : 0.85), location: 0),
                        .init(color: .white.opacity(scheme == .dark ? 0.06 : 0.30), location: 0.45),
                        .init(color: .black.opacity(scheme == .dark ? 0.18 : 0.05), location: 1),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1)
    }
}

extension View {
    /// 어떤 것이든 유리판 위에 올린다.
    ///
    /// - `material`: 얼마나 두꺼운 유리인지. 목록 카드는 얇게(.ultraThin),
    ///   위에 뜨는 창은 두껍게(.regular) 쓴다. 두꺼울수록 뒤가 덜 비친다.
    func glass(radius: CGFloat = Theme.radius,
               material: Material = .ultraThinMaterial,
               shadow: Bool = true) -> some View {
        self
            .background(material, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(GlassStroke(radius: radius))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            // 유리는 떠 있어야 한다. 그림자가 없으면 배경에 붙어 보인다.
            // 두 겹으로 준다. 좁고 진한 것과 넓고 옅은 것.
            .shadow(color: .black.opacity(shadow ? 0.06 : 0), radius: 3, y: 1)
            .shadow(color: Color(hex: 0x4B2A7A).opacity(shadow ? 0.10 : 0), radius: 20, y: 10)
    }
}

/// 목록에 쓰는 유리 카드
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = Theme.radius
    var material: Material = .ultraThinMaterial
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glass(radius: radius, material: material)
    }
}

// ─────────────────────────────────────────────────────────
// 단추
// ─────────────────────────────────────────────────────────

/// 주요 단추. 색을 칠하되 위쪽에 빛 반사를 얹어 유리처럼 보이게 한다.
struct BrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.brand)
                    .overlay {
                        // 위쪽 절반에 걸리는 빛. 단추가 볼록해 보인다
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0)],
                                    startPoint: .top, endPoint: .center))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.4), lineWidth: 0.8)
                    }
            }
            .shadow(color: Theme.purple.opacity(0.38), radius: 14, y: 6)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

/// 유리 단추. 색 없이 뒤가 비친다.
struct GlassButtonStyle: ButtonStyle {
    var radius: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .glass(radius: radius, material: .thinMaterial)
            .opacity(configuration.isPressed ? 0.75 : 1)
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
