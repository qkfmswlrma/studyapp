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
                            ScreenHeader(title: "내 기록") { EmptyView() }

                            Picker("", selection: $wrongOnly) {
                                Text("푼 시험").tag(false)
                                Text("오답노트").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 20)

                            if rows.isEmpty {
                                EmptyNote(text: wrongOnly
                                          ? "틀린 문제가 없어요"
                                          : "아직 푼 시험이 없어요")
                                    .padding(.horizontal, 20)
                            } else if wrongOnly {
                                ForEach(wrongItems, id: \.id) { item in
                                    GlassCard {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text(item.examTitle)
                                                .font(.system(size: 13, weight: .heavy))
                                                .foregroundStyle(.secondary)
                                            QuestionBodyOrLegacy(question: item.question)
                                            if let accept = item.question.accept, !accept.isEmpty {
                                                Text("정답  \(accept)")
                                                    .font(.system(size: 13.5, weight: .bold))
                                                    .foregroundStyle(Theme.green)
                                            } else if let ans = item.question.answer {
                                                Text("정답  \(ans + 1)번")
                                                    .font(.system(size: 13.5, weight: .bold))
                                                    .foregroundStyle(Theme.green)
                                            }
                                        }
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
        let question: Question
    }

    /// 틀린 문제만 모은다. 정답이 지워진 채로 온 시험은 여기 안 나온다.
    private var wrongItems: [WrongItem] {
        rows.flatMap { row in
            row.exam.questions.compactMap { q in
                guard !Grading.countsCorrect(q, in: row.sub) else { return nil }
                return WrongItem(id: "\(row.sub.id)-\(q.id)",
                                 examTitle: row.exam.title, question: q)
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
                    Text("\(Int(Grading.total(exam, sub)))")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Theme.purple)
                    Text("/ \(Int(exam.maxScore))")
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

                    Button("로그아웃") {
                        Task {
                            await store.signOut()
                            dismiss()
                        }
                    }
                    .buttonStyle(GlassButtonStyle())
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
        }
        .navigationTitle("내 정보")
        .navigationBarTitleDisplayMode(.inline)
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
