import SwiftUI

@main
struct SuhakApp: App {
    @StateObject private var store = Store()

    init() {
        // 탭 막대도 유리로. 기본값은 불투명해서 뒤가 안 비친다.
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

    var body: some View {
        ZStack {
            AppBackground()

            if store.loading {
                SplashView()
            } else {
                TabView {
                    HomeScreen(authOpen: $authOpen)
                        .tabItem { Label("홈", systemImage: "house.fill") }

                    PostListScreen(kind: .notice)
                        .tabItem { Label("공지", systemImage: "megaphone.fill") }

                    PostListScreen(kind: .column)
                        .tabItem { Label("칼럼", systemImage: "book.fill") }

                    ExamChooserScreen()
                        .tabItem { Label("시험", systemImage: "list.clipboard.fill") }

                    RecordsScreen()
                        .tabItem { Label("기록", systemImage: "chart.bar.fill") }
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

/// 스크롤해서 올라간 내용이 제목줄 뒤로 비쳐 지나간다.
/// 이게 유리를 쓰는 이유다. 안 비치면 그냥 색칠한 막대다.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

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
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
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
