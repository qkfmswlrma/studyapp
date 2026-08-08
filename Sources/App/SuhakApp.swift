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
    @State private var tab = Launch.tab

    var body: some View {
        ZStack {
            AppBackground()

            if store.loading {
                SplashView()
            } else {
                // 시안과 같은 다섯 개다.
                // 공지와 게임은 탭을 차지할 만큼 자주 열지 않아서 홈에서 들어간다.
                TabView(selection: $tab) {
                    HomeScreen(authOpen: $authOpen, tab: $tab)
                        .tabItem { Label("홈", systemImage: "house.fill") }
                        .tag(0)

                    PostListScreen(kind: .column)
                        .tabItem { Label("칼럼", systemImage: "book.fill") }
                        .tag(1)

                    ExamChooserScreen()
                        .tabItem { Label("시험", systemImage: "list.clipboard.fill") }
                        .tag(2)

                    MockScreen()
                        .tabItem { Label("모의", systemImage: "timer") }
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
                .background(Theme.buttonFill,
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .shadow(color: Theme.purple.opacity(0.3), radius: 16, y: 8)
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
// 화면 위쪽 제목
// ─────────────────────────────────────────────────────────

// 화면 제목은 `ScreenTitle` 을 내용 맨 위에 그냥 넣는다 (Theme.swift).
//
// 예전에는 유리 제목줄을 띄워뒀는데 시안을 따라 걷어냈다.
// **유리는 화면에 한두 개만 있어야 한다.** 탭 막대가 이미 유리라
// 제목줄까지 띄우면 유리가 유리를 굴절시켜 둘 다 허옇게 뜬다.
// 굴절시킬 내용이 있어야 유리가 유리로 보인다.

/// 로그인 단추 또는 회원 아이콘
struct AccountButton: View {
    @EnvironmentObject var store: Store
    @Binding var authOpen: Bool

    var body: some View {
        if store.loggedIn {
            // 시안의 "고등 회원" 배지 자리.
            // 떠 있는 조작 요소라 여기는 유리가 맞다.
            NavigationLink { AccountScreen() } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.purple)
                        .frame(width: 8, height: 8)
                    Text(store.isAdmin ? "관리자" : "회원")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.t1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glass(radius: 999, material: .thinMaterial, interactive: true)
            }
        } else {
            Button("로그인") { authOpen = true }
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 17).padding(.vertical, 10)
                .background(Theme.buttonFill, in: Capsule())
                .shadow(color: Theme.purple.opacity(0.26), radius: 10, y: 4)
        }
    }
}
