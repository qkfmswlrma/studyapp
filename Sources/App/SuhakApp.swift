import SwiftUI

@main
struct SuhakApp: App {
    @StateObject private var store = Store()

    init() {
        // iOS 26 은 탭 막대와 제목줄을 스스로 리퀴드 글래스로 그린다.
        // 여기서 손대면 그걸 덮어써서 오히려 옛날 모양이 된다. 건드리지 않는다.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { return }
        #endif

        // iOS 25 이하에서만 손으로 유리를 깐다. 기본값은 불투명해서 뒤가 안 비친다.
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { await store.bootstrap() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var authOpen = false
    @State private var tab = RootView.startTab

    /// CI 가 화면을 찍을 때 탭을 골라 켤 수 있게 한다.
    /// 윈도우에서는 앱을 못 띄우니, 탭마다 찍어봐야 무엇이 잘못됐는지 안다.
    ///   xcrun simctl launch <기기> <앱> --tab 1
    static var startTab: Int {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--tab"), i + 1 < args.count else { return 0 }
        return Int(args[i + 1]) ?? 0
    }

    var body: some View {
        ZStack {
            AppBackground()

            if store.loading {
                SplashView()
            } else {
                TabView(selection: $tab) {
                    HomeScreen(authOpen: $authOpen)
                        .tabItem { Label("홈", systemImage: "house.fill") }
                        .tag(0)

                    PostListScreen(kind: .notice)
                        .tabItem { Label("공지", systemImage: "megaphone.fill") }
                        .tag(1)

                    PostListScreen(kind: .column)
                        .tabItem { Label("칼럼", systemImage: "book.fill") }
                        .tag(2)

                    ExamChooserScreen()
                        .tabItem { Label("시험", systemImage: "list.clipboard.fill") }
                        .tag(3)

                    RecordsScreen()
                        .tabItem { Label("기록", systemImage: "chart.bar.fill") }
                        .tag(4)
                }
                .tint(Theme.purple)
            }
        }
        .sheet(isPresented: $authOpen) { AuthSheet() }
    }
}

/// 사이트의 "불러오는 중" 화면과 같은 모양
struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 16) {
            Text("∫")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Theme.brand)
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(LinearGradient(colors: [.white.opacity(0.4), .clear],
                                                     startPoint: .top, endPoint: .center))
                        }
                }
                .shadow(color: Theme.purple.opacity(0.4), radius: 16, y: 8)
                .scaleEffect(pulse ? 1.04 : 0.96)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)

            Text("수학질문방 불러오는 중…")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .onAppear { pulse = true }
    }
}

// ─────────────────────────────────────────────────────────
// 화면 위쪽 제목줄
// ─────────────────────────────────────────────────────────

extension View {
    /// 제목줄을 내용 위에 띄운다.
    ///
    /// 내용 안에 같이 넣으면 같이 스크롤돼서 유리를 쓸 이유가 없어진다.
    /// 떠 있어야 카드가 그 뒤로 지나가고, 그때 유리가 내용을 굴절시킨다.
    /// 이게 리퀴드 글래스를 쓰는 이유다.
    func floatingHeader<T: View>(_ title: String,
                                 @ViewBuilder trailing: () -> T) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: title, trailing: trailing())
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
        }
    }
}

struct ScreenHeader<Trailing: View>: View {
    let title: String
    var trailing: Trailing

    init(title: String, trailing: Trailing) {
        self.title = title
        self.trailing = trailing
    }

    init(title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 11) {
            Text("∫")
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Theme.brand)
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                     startPoint: .top, endPoint: .center))
                        }
                }
                .shadow(color: Theme.purple.opacity(0.35), radius: 10, y: 4)

            Text(title)
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(.primary)

            Spacer()
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // 여기가 유리다. 카드가 이 뒤로 지나간다.
        .glass(radius: 30)
    }
}

/// 로그인 단추 또는 회원 아이콘
struct AccountButton: View {
    @EnvironmentObject var store: Store
    @Binding var authOpen: Bool

    var body: some View {
        if store.loggedIn {
            NavigationLink { AccountScreen() } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .glass(radius: 20, material: .thinMaterial)
            }
        } else {
            Button("로그인") { authOpen = true }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 17).padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(Theme.brand)
                        .overlay {
                            Capsule().fill(LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .top, endPoint: .center))
                        }
                }
                .shadow(color: Theme.purple.opacity(0.35), radius: 10, y: 4)
        }
    }
}
