import SwiftUI

// ─────────────────────────────────────────────────────────
// 내 기록과 오답노트
// ─────────────────────────────────────────────────────────

struct RecordsScreen: View {
    @EnvironmentObject var store: Store
    @State private var wrongOnly = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if !store.loggedIn {
                    LoginNeeded(what: "내 기록")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ScreenTitle(text: "내 기록")
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                            Picker("", selection: $wrongOnly) {
                                Text("푼 시험").tag(false)
                                Text("오답노트").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 20)

                            // 다 맞혔을 때도 안내가 떠야 한다.
                            // 푼 시험이 있는지가 아니라, 지금 보여줄 것이 있는지로 가른다.
                            if wrongOnly && wrongItems.isEmpty {
                                EmptyNote(text: rows.isEmpty
                                          ? "아직 푼 시험이 없어요"
                                          : "틀린 문제가 없어요")
                                    .padding(.horizontal, 20)
                            } else if !wrongOnly && rows.isEmpty {
                                EmptyNote(text: "아직 푼 시험이 없어요")
                                    .padding(.horizontal, 20)
                            } else if wrongOnly {
                                Text("틀린 문제만 모았어요. 해설이 있으면 함께 볼 수 있어요")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.t3)
                                    .padding(.horizontal, 22)

                                ForEach(wrongItems, id: \.id) { item in
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(item.examTitle)
                                            .font(.system(size: 12.5, weight: .heavy))
                                            .foregroundStyle(Theme.t3)
                                            .padding(.horizontal, 4)
                                        // 채점 결과와 같은 카드를 쓴다. 내 답과 정답, 해설이 한 벌로 붙어 있다.
                                        ReviewCard(index: item.index,
                                                   question: item.question,
                                                   submission: item.submission,
                                                   stat: nil)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            } else {
                                ForEach(rows, id: \.sub.id) { row in
                                    NavigationLink {
                                        ReviewScreen(exam: row.exam, submission: row.sub)
                                    } label: {
                                        RecordRow(exam: row.exam, sub: row.sub)
                                    }
                                    .buttonStyle(PressableCardStyle())
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .refreshable { await store.reload() }
                }
            }
        }
    }

    private struct Row { let exam: Exam; let sub: Submission }

    private var rows: [Row] {
        store.submissions.compactMap { sub in
            guard let exam = store.exams.first(where: { $0.id == sub.examId }) else { return nil }
            return Row(exam: exam, sub: sub)
        }
    }

    private struct WrongItem: Identifiable {
        let id: String
        let examTitle: String
        let index: Int
        let question: Question
        let submission: Submission
    }

    /// 틀린 문제만 모은다. 정답이 지워진 채로 온 시험은 여기 안 나온다.
    private var wrongItems: [WrongItem] {
        rows.flatMap { row in
            row.exam.questions.indices.compactMap { i -> WrongItem? in
                let q = row.exam.questions[i]
                guard !Grading.countsCorrect(q, in: row.sub) else { return nil }
                return WrongItem(id: "\(row.sub.id)-\(q.id)",
                                 examTitle: row.exam.title,
                                 index: i + 1,
                                 question: q,
                                 submission: row.sub)
            }
        }
    }
}

struct RecordRow: View {
    let exam: Exam
    let sub: Submission

    var body: some View {
        GlassCard(padding: 17) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(exam.title)
                        .font(.system(size: 15.5, weight: .heavy))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let date = sub.submittedAt {
                        Text(date, format: .dateTime.year().month().day())
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 1) {
                    Text(Grading.total(exam, sub).scoreText)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Theme.purple)
                    Text("/ \(exam.maxScore.scoreText)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct LoginNeeded: View {
    let what: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Theme.brand, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Theme.purple.opacity(0.35), radius: 14, y: 6)
            Text("\(what)은 로그인이 필요해요")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.primary)
            Text("홈 화면 오른쪽 위에서 로그인할 수 있어요")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }
}

// ─────────────────────────────────────────────────────────
// 계정
// ─────────────────────────────────────────────────────────

struct AccountScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var kakaoId = ""
    @State private var tamgu1 = ""
    @State private var tamgu2 = ""
    @State private var newPassword = ""
    @State private var note: String?
    @State private var noteIsError = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    GlassCard(padding: 24, material: .regularMaterial, frosted: true) {
                        VStack(spacing: 12) {
                            Text(String(store.profile?.username.prefix(1) ?? "?"))
                                .font(.system(size: 26, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 72, height: 72)
                                .background(Theme.brand, in: Circle())
                                .shadow(color: Theme.purple.opacity(0.35), radius: 14, y: 6)

                            Text(store.profile?.username ?? "")
                                .font(.system(size: 19, weight: .heavy))
                                .foregroundStyle(.primary)

                            if store.isAdmin {
                                Text("관리자")
                                    .font(.system(size: 11.5, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 11).padding(.vertical, 4)
                                    .background(Theme.brand, in: Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    GlassCard(padding: 0) {
                        VStack(spacing: 0) {
                            infoRow("푼 시험", "\(store.submissions.count)개")
                            Divider().opacity(0.4)
                            infoRow("가입일", store.profile?.createdAt.map {
                                $0.formatted(.dateTime.year().month().day())
                            } ?? "-")
                        }
                    }

                    GlassCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("채팅방 닉네임")
                                .font(.system(size: 13.5, weight: .heavy))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                TextField("닉네임", text: $kakaoId)
                                    .font(.system(size: 15, weight: .semibold))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 11))
                                Button("저장") { Task { await saveKakao() } }
                                    .buttonStyle(GlassButtonStyle(radius: 11))
                            }
                        }
                    }

                    // 탐구는 사람마다 고른 과목이 달라서 여기서 정한다.
                    // 모의고사 화면이 "탐구 1" 대신 이 이름을 보여준다.
                    GlassCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("탐구 과목")
                                .font(.system(size: 13.5, weight: .heavy))
                                .foregroundStyle(.secondary)
                            tamguPicker("탐구 1", selection: $tamgu1)
                            tamguPicker("탐구 2", selection: $tamgu2)
                            Button("저장") { Task { await saveTamgu() } }
                                .buttonStyle(GlassButtonStyle(radius: 11))
                        }
                    }

                    GlassCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("비밀번호 바꾸기")
                                .font(.system(size: 13.5, weight: .heavy))
                                .foregroundStyle(.secondary)
                            SecureField("새 비밀번호", text: $newPassword)
                                .font(.system(size: 15, weight: .semibold))
                                .padding(12)
                                .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 11))
                            Button("바꾸기") { Task { await savePassword() } }
                                .buttonStyle(GlassButtonStyle(radius: 11))
                        }
                    }

                    if let note {
                        Text(note)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(noteIsError ? Theme.red : Theme.green)
                    }

                    // 관리자가 아니면 이 줄 자체가 없다.
                    // "권한이 없습니다" 같은 안내를 띄우지 않는다.
                    if store.isAdmin {
                        NavigationLink { AdminScreen() } label: {
                            GlassCard(padding: 16) {
                                HStack {
                                    Text("관리자")
                                        .font(.system(size: 15, weight: .heavy))
                                        .foregroundStyle(Theme.t1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.t3)
                                }
                            }
                        }
                        .buttonStyle(PressableCardStyle())
                    }

                    Button("로그아웃") {
                        Task {
                            await store.signOut()
                            dismiss()
                        }
                    }
                    .buttonStyle(GlassButtonStyle())
                    .frame(maxWidth: .infinity)

                    Button("탈퇴하기") { confirmDelete = true }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.t3)
                        .underline()
                        .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .navigationTitle("내 정보")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            kakaoId = store.profile?.kakaoId ?? ""
            tamgu1 = store.profile?.tamgu1 ?? ""
            tamgu2 = store.profile?.tamgu2 ?? ""
        }
        .alert("정말 탈퇴할까요?", isPresented: $confirmDelete) {
            Button("탈퇴", role: .destructive) { Task { await deleteMe() } }
            Button("그만두기", role: .cancel) {}
        } message: {
            Text("푼 기록과 오답노트가 모두 지워지고 되돌릴 수 없어요.")
        }
    }

    private func saveKakao() async {
        do {
            try await store.updateKakaoId(kakaoId)
            show("닉네임을 저장했어요", error: false)
        } catch {
            show(store.message(for: error), error: true)
        }
    }

    private func tamguPicker(_ label: String, selection: Binding<String>) -> some View {
        Picker(label, selection: selection) {
            Text("고르지 않음").tag("")
            ForEach(TAMGU_CHOICES) { choice in
                Section(choice.group) {
                    ForEach(choice.items, id: \.self) { Text($0).tag($0) }
                }
            }
        }
        .pickerStyle(.menu)
        .tint(Theme.purple)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func saveTamgu() async {
        do {
            try await store.updateTamgu(tamgu1, tamgu2)
            show("탐구 과목을 저장했어요", error: false)
        } catch {
            show(store.message(for: error), error: true)
        }
    }

    private func savePassword() async {
        do {
            try await store.changePassword(newPassword)
            newPassword = ""
            show("비밀번호를 바꿨어요", error: false)
        } catch {
            show(store.message(for: error), error: true)
        }
    }

    private func deleteMe() async {
        do {
            try await store.deleteMyAccount()
            dismiss()
        } catch {
            show(store.message(for: error), error: true)
        }
    }

    private func show(_ text: String, error: Bool) {
        note = text
        noteIsError = error
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }
}
