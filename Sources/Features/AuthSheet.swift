import SwiftUI

/// 로그인과 회원가입.
/// 사이트와 같은 방식이라 사이트에서 만든 계정으로 그대로 들어온다.
struct AuthSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var signingUp = false
    @State private var username = ""
    @State private var password = ""
    @State private var passwordAgain = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        Text(signingUp ? "회원가입" : "로그인")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Theme.t1)
                            .padding(.top, 8)

                        VStack(spacing: 10) {
                            field("아이디", text: $username)
                            secureField("비밀번호", text: $password)
                            if signingUp {
                                secureField("비밀번호 다시", text: $passwordAgain)
                            }
                        }

                        if let error {
                            Text(error)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Theme.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(signingUp ? "가입하기" : "로그인") {
                            Task { await go() }
                        }
                        .buttonStyle(BrandButtonStyle())
                        .disabled(busy)
                        .opacity(busy ? 0.6 : 1)

                        Button(signingUp ? "이미 계정이 있어요" : "계정 만들기") {
                            signingUp.toggle()
                            error = nil
                        }
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Theme.blue)
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(Theme.t2)
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(15)
            .glass(radius: 14, material: .thinMaterial, shadow: false)
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        SecureField(label, text: text)
            .padding(15)
            .glass(radius: 14, material: .thinMaterial, shadow: false)
    }

    private func go() async {
        error = nil
        busy = true
        defer { busy = false }
        do {
            if signingUp {
                guard password == passwordAgain else {
                    error = "비밀번호가 서로 달라요."
                    return
                }
                try await store.signUp(username: username, password: password)
            } else {
                try await store.signIn(username: username, password: password)
            }
            dismiss()
        } catch {
            self.error = store.message(for: error)
        }
    }
}
