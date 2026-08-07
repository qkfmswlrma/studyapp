import SwiftUI

// ─────────────────────────────────────────────────────────
// 시험 종류 고르기
// ─────────────────────────────────────────────────────────

struct ExamChooserScreen: View {
    @EnvironmentObject var store: Store
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(spacing: 12) {
                            NavigationLink(value: ExamType.level) {
                                pick("레벨테스트", "실력을 확인해요", "chart.line.uptrend.xyaxis", Theme.purple)
                            }
                            .buttonStyle(PressableCardStyle())

                            NavigationLink(value: ExamType.today) {
                                pick("오늘의 문제", "하루 한 문제씩 풀어요", "sun.max.fill", Theme.pink)
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 24)
                }
                .floatingHeader("시험") { EmptyView() }
            }
            .navigationDestination(for: ExamType.self) { ExamListScreen(type: $0) }
            .navigationDestination(for: Exam.self) { ExamEntryScreen(exam: $0) }
        }
        // 화면을 찍을 때만 쓴다. 인자가 없으면 아무 일도 하지 않는다.
        .task { openForScreenshot() }
    }

    /// 시험 목록과 응시 화면은 손으로 눌러 들어가야 나오는데 시뮬레이터에는 손가락이 없다.
    /// 여기가 제일 확인이 급한 화면이다. 문항과 수식이 제대로 그려지는지는 눈으로만 안다.
    private func openForScreenshot() {
        switch Launch.open {
        case "exam-list":
            path.append(ExamType.level)
        case "exam-today":
            path.append(ExamType.today)
        case "exam-take":
            path.append(ExamType.level)
            if let exam = store.exams(of: .level).first { path.append(exam) }
        default:
            break
        }
    }

    private func pick(_ title: String, _ sub: String,
                      _ icon: String, _ color: Color) -> some View {
        GlassCard(padding: 22) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(color)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                         startPoint: .top, endPoint: .center))
                            }
                    }
                    .shadow(color: color.opacity(0.35), radius: 12, y: 5)
                Text(title)
                    .font(.system(size: 16.5, weight: .heavy))
                    .foregroundStyle(.primary)
                Text(sub)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// ─────────────────────────────────────────────────────────
// 시험 목록
// ─────────────────────────────────────────────────────────

struct ExamListScreen: View {
    @EnvironmentObject var store: Store
    let type: ExamType

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    if items.isEmpty {
                        EmptyNote(text: "아직 시험이 없어요")
                    } else {
                        ForEach(items) { exam in
                            NavigationLink(value: exam) {
                                ExamRow(exam: exam,
                                        stat: store.examStats[exam.id],
                                        solved: store.mySubmission(examId: exam.id) != nil)
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                }
                .padding(20)
            }
            .refreshable { await store.reload() }
        }
        .navigationTitle(type.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var items: [Exam] { store.exams(of: type) }
}

struct ExamRow: View {
    @EnvironmentObject var store: Store
    let exam: Exam
    let stat: ExamStat?
    let solved: Bool

    var body: some View {
        GlassCard(padding: 17) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text(exam.title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if store.isUnread(exam) {
                        Circle().fill(Theme.red).frame(width: 7, height: 7)
                    }
                    Spacer(minLength: 0)
                    if solved {
                        Text("푼 문제")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.green)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Theme.green.opacity(0.14), in: Capsule())
                    }
                }

                HStack(spacing: 10) {
                    label("문항 \(exam.questions.count)개")
                    if let rate = stat?.rate {
                        label("정답률 \(Int(rate * 100))%", color: Theme.rateColor(rate))
                    }
                    Spacer(minLength: 0)
                    Text(exam.author.isEmpty ? "관리자" : exam.author)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func label(_ text: String, color: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color ?? .secondary)
    }
}

// ─────────────────────────────────────────────────────────
// 시험 들어가기. 이미 푼 시험이면 채점 결과로 바로 간다.
// ─────────────────────────────────────────────────────────

struct ExamEntryScreen: View {
    @EnvironmentObject var store: Store
    let exam: Exam

    var body: some View {
        if let sub = store.mySubmission(examId: exam.id) {
            ReviewScreen(exam: exam, submission: sub)
        } else {
            TakeExamScreen(exam: exam)
        }
    }
}

// ─────────────────────────────────────────────────────────
// 응시
// ─────────────────────────────────────────────────────────

struct TakeExamScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let exam: Exam
    @State private var answers: [String: JSONValue] = [:]
    @State private var submitting = false
    @State private var error: String?
    @State private var result: (Exam, Submission)?
    @State private var guestDone = false

    var body: some View {
        ZStack {
            AppBackground()

            if let result {
                ReviewScreen(exam: result.0, submission: result.1)
            } else if guestDone {
                GuestDoneNote()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(exam.questions.enumerated()), id: \.element.id) { i, q in
                            QuestionCard(index: i + 1, question: q,
                                         answer: binding(for: q))
                        }

                        if let error {
                            Text(error)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Theme.red)
                        }

                        Button(submitting ? "제출 중…" : "제출하기") {
                            Task { await submit() }
                        }
                        .buttonStyle(BrandButtonStyle())
                        .disabled(submitting || !allAnswered)
                        .opacity(allAnswered ? 1 : 0.5)

                        if !allAnswered {
                            Text("아직 답하지 않은 문제가 있어요")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }

                        // 비회원도 풀 수 있다. 기록만 안 남는다.
                        if !store.loggedIn {
                            GlassCard {
                                Text("로그인하면 푼 기록이 남고 오답노트에서 다시 볼 수 있어요")
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(exam.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.markRead(exam: exam) }
    }

    private var allAnswered: Bool {
        exam.questions.allSatisfy { q in
            guard let a = answers[q.id] else { return false }
            return !a.isEmpty
        }
    }

    private func binding(for q: Question) -> Binding<JSONValue?> {
        Binding(
            get: { answers[q.id] },
            set: { answers[q.id] = $0 })
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }
        do {
            if store.loggedIn {
                let sub = try await store.submit(exam: exam, answers: answers)
                // 제출하면 서버가 정답을 붙여서 다시 내준다. 그걸 받아 채점 화면에 쓴다.
                let fresh = try? await Supa.exam(id: exam.id)
                let full = fresh.map { exam.merging(answersFrom: $0.questions) } ?? exam
                result = (full, sub)
            } else {
                // 비회원은 표에 못 쓴다. 서버 함수로만 들어가고 하루 한 번만 받아준다.
                try await store.submitAsGuest(exam: exam, answers: answers)
                guestDone = true
            }
        } catch {
            self.error = store.message(for: error)
        }
    }
}

/// 비회원이 냈을 때. 채점 결과를 보여줄 수 없다.
/// 정답을 내주면 로그인 없이 답만 긁어갈 수 있어서 서버가 안 준다.
struct GuestDoneNote: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Theme.green)
            Text("냈어요")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(.primary)
            Text("로그인하고 풀면 채점 결과와 해설을 바로 볼 수 있어요")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }
}

struct QuestionCard: View {
    let index: Int
    let question: Question
    @Binding var answer: JSONValue?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 8) {
                    Text("\(index)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Theme.brand, in: Circle())
                    Text("\(question.points.scoreText)점")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                QuestionBodyOrLegacy(question: question)

                if let image = question.image, let url = URL(string: image) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial).frame(height: 140)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if question.type == .mc {
                    VStack(spacing: 8) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { i, option in
                            OptionRow(number: i + 1, text: option,
                                      selected: answer?.asInt == i) {
                                answer = .int(i)
                            }
                        }
                    }
                } else {
                    TextField("답을 적어주세요", text: Binding(
                        get: { answer?.asString ?? "" },
                        set: { answer = $0.isEmpty ? nil : .string($0) }))
                        .font(.system(size: 15.5, weight: .semibold))
                        .padding(14)
                        .glass(radius: 13, material: .thinMaterial, shadow: false)
                }
            }
        }
    }
}

struct OptionRow: View {
    let number: Int
    let text: String
    let selected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 11) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(selected ? .white : .secondary)
                    .frame(width: 25, height: 25)
                    .background {
                        if selected { Circle().fill(Theme.brand) }
                        else { Circle().fill(.ultraThinMaterial) }
                    }
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .glass(radius: 13,
                   material: selected ? .regularMaterial : .ultraThinMaterial,
                   shadow: false)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Theme.purple.opacity(0.55), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(PressableCardStyle())
    }
}

// ─────────────────────────────────────────────────────────
// 채점 결과
// ─────────────────────────────────────────────────────────

struct ReviewScreen: View {
    @EnvironmentObject var store: Store
    let exam: Exam
    let submission: Submission

    @State private var stats: [String: QuestionStat] = [:]
    @State private var full: Exam?

    private var shown: Exam { full ?? exam }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScoreCard(exam: shown, submission: submission)

                    ForEach(Array(shown.questions.enumerated()), id: \.element.id) { i, q in
                        ReviewCard(index: i + 1, question: q,
                                   submission: submission,
                                   stat: stats[q.id])
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(exam.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 정답이 지워진 채로 들고 있으면 정답을 붙여 다시 받아온다
            if exam.answersHidden, let fresh = try? await Supa.exam(id: exam.id) {
                full = exam.merging(answersFrom: fresh.questions)
            }
            stats = (try? await Supa.questionStats(examId: exam.id)) ?? [:]
        }
    }
}

struct ScoreCard: View {
    let exam: Exam
    let submission: Submission

    private var score: Double { Grading.total(exam, submission) }
    private var ratio: Double { exam.maxScore > 0 ? score / exam.maxScore : 0 }

    var body: some View {
        GlassCard(padding: 24, material: .regularMaterial, frosted: true) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(Theme.brand,
                                style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(score.scoreText)
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(.primary)
                        Text("/ \(exam.maxScore.scoreText)점")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 150)
                .padding(.vertical, 4)

                let correct = exam.questions.filter { Grading.countsCorrect($0, in: submission) }.count
                Text("\(exam.questions.count)문제 중 \(correct)문제를 맞혔어요")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct ReviewCard: View {
    let index: Int
    let question: Question
    let submission: Submission
    let stat: QuestionStat?

    @State private var showExplain = false

    private var correct: Bool { Grading.countsCorrect(question, in: submission) }
    private var myAnswer: String {
        guard let a = submission.answers[question.id] else { return "답 없음" }
        if question.type == .mc, let i = a.asInt {
            return i < question.options.count ? "\(i + 1)번  \(question.options[i])" : "\(i + 1)번"
        }
        return a.asString
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("\(index)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Theme.brand, in: Circle())

                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(correct ? Theme.green : Theme.red)

                    Spacer()

                    if let rate = stat?.rate {
                        Text("정답률 \(Int(rate * 100))%")
                            .font(.system(size: 11.5, weight: .heavy))
                            .foregroundStyle(Theme.rateColor(rate))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Theme.rateColor(rate).opacity(0.14), in: Capsule())
                    }
                }

                QuestionBodyOrLegacy(question: question)

                VStack(alignment: .leading, spacing: 5) {
                    row("내 답", myAnswer, correct ? Theme.green : Theme.red)
                    if !correct {
                        if question.type == .mc, let ans = question.answer {
                            row("정답", ans < question.options.count
                                ? "\(ans + 1)번  \(question.options[ans])" : "\(ans + 1)번",
                                Theme.green)
                        } else if let accept = question.accept, !accept.isEmpty {
                            row("정답", accept, Theme.green)
                        }
                    }
                }

                if question.hasExplain {
                    if showExplain {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("💡 해설")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(.secondary)
                            QuestionBodyView(question.explain ?? [], fontSize: 15)
                        }
                        .padding(14)
                        .glass(radius: 13, material: .thinMaterial, shadow: false)
                    } else {
                        Button("💡 해설 보기") { withAnimation { showExplain = true } }
                            .buttonStyle(GlassButtonStyle())
                    }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12.5, weight: .heavy))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            Spacer(minLength: 0)
        }
    }
}
