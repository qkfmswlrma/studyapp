import SwiftUI

// ─────────────────────────────────────────────────────────
// 오늘의 문제
//
// 목록을 거치지 않는다. 들어오면 오늘 문제가 바로 나오고,
// 며칠 연속으로 풀었는지와 이번 달 달력이 아래에 붙는다.
// 하루에 하나만 푸는 것이라 시험 목록처럼 늘어놓을 이유가 없다.
// ─────────────────────────────────────────────────────────

struct DailyPuzzleScreen: View {
    @EnvironmentObject var store: Store

    @State private var answer: JSONValue?
    @State private var submitting = false
    @State private var error: String?
    @State private var solved: Submission?
    @State private var graded: Exam?
    @State private var guestDone = false
    @State private var month = Date()
    /// 달력에서 고른 날. 비어 있으면 오늘 것을 본다.
    @State private var picked: Date?

    /// 오늘 낼 문제. 서버가 공개된 것만 내려주므로 맨 앞이 오늘 것이다.
    private var today: Exam? { store.exams(of: .today).first }

    /// 지금 화면에 띄운 문제. 달력에서 고르면 그날 것으로 바뀐다.
    private var shown: Exam? {
        if let picked { return store.dailyExam(on: picked) }
        return today
    }

    private var isToday: Bool {
        guard let picked else { return true }
        return Calendar.current.isDateInToday(picked)
    }

    /// 이미 푼 기록. 화면을 다시 열어도 결과가 그대로 보인다.
    private var submission: Submission? {
        guard let exam = shown else { return nil }
        return solved ?? store.mySubmission(examId: exam.id)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let exam = shown {
                        header(exam)
                        puzzle(exam)
                    } else {
                        EmptyNote(text: picked == nil
                                  ? "오늘은 아직 문제가 없어요"
                                  : "그날은 문제가 없었어요")
                    }

                    DailyCalendarCard(month: $month, picked: $picked,
                                      shownId: shown?.id)
                }
                .padding(20)
            }
        }
        .navigationTitle("오늘의 문제")
        .navigationBarTitleDisplayMode(.inline)
        // 다른 날로 바꾸면 앞 문제에 적던 답이 남아 있으면 안 된다
        .onChange(of: shown?.id) { _ in
            answer = nil
            error = nil
            solved = nil
            graded = nil
            guestDone = false
        }
        .task {
            if let exam = shown { await store.markRead(exam: exam) }
        }
    }

    // ── 머리말 ──────────────────────────────────────────

    private func header(_ exam: Exam) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateLabel(exam))
                .font(.system(size: 12.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(Theme.purple)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(isToday ? "오늘의 문제" : "지난 문제")
                    .font(.system(size: 27, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.t1)
                Spacer(minLength: 0)
                if isToday, store.dailyStreak > 0 {
                    Text("🔥 \(store.dailyStreak)일 연속")
                        .font(.system(size: 12.5, weight: .heavy))
                        .foregroundStyle(Theme.pink)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Theme.tagBackground, in: Capsule())
                } else if !isToday {
                    Button("오늘로") { picked = nil }
                        .font(.system(size: 12.5, weight: .heavy))
                        .foregroundStyle(Theme.purple)
                }
            }
        }
    }

    private func dateLabel(_ exam: Exam) -> String {
        guard let date = exam.publishAt ?? exam.createdAt else { return exam.title }
        return date.formatted(.dateTime.year().month().day())
    }

    // ── 문제 ────────────────────────────────────────────

    @ViewBuilder
    private func puzzle(_ exam: Exam) -> some View {
        if let sub = submission {
            DailyResultCard(exam: graded ?? exam, submission: sub)
        } else if guestDone {
            GlassCard { GuestDoneNote() }
        } else if let question = exam.questions.first {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    QuestionBodyOrLegacy(question: question)

                    if let image = question.image, let url = URL(string: image) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFit()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial).frame(height: 140)
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
                            .font(.system(size: 16, weight: .semibold))
                            .padding(14)
                            .glass(radius: 13, material: .thinMaterial, shadow: false)
                    }

                    if let error {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.red)
                    }

                    Button(submitting ? "내는 중…" : "확인") {
                        Task { await submit(exam: exam, question: question) }
                    }
                    .buttonStyle(BrandButtonStyle())
                    .disabled(submitting || answer == nil || (answer?.isEmpty ?? true))
                    .opacity(answer == nil || (answer?.isEmpty ?? true) ? 0.5 : 1)

                    if !store.loggedIn {
                        Text("로그인하면 푼 기록이 남고 연속 기록도 쌓여요")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.t3)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func submit(exam: Exam, question: Question) async {
        submitting = true
        defer { submitting = false }
        let answers: [String: JSONValue] = [question.id: answer ?? .null]
        do {
            if store.loggedIn {
                let sub = try await store.submit(exam: exam, answers: answers)
                // 내고 나면 서버가 정답과 해설을 붙여 다시 내준다
                let fresh = try? await Supa.exam(id: exam.id)
                graded = fresh.map { exam.merging(answersFrom: $0.questions) } ?? exam
                solved = sub
            } else {
                try await store.submitAsGuest(exam: exam, answers: answers)
                guestDone = true
            }
        } catch {
            self.error = store.message(for: error)
        }
    }
}

// ─────────────────────────────────────────────────────────
// 낸 뒤에 보는 것
// ─────────────────────────────────────────────────────────

/// 맞았는지 먼저 크게 보여주고, 그다음 정답과 해설, 몇 %가 맞혔는지를 붙인다.
struct DailyResultCard: View {
    @EnvironmentObject var store: Store
    let exam: Exam
    let submission: Submission

    @State private var stats: [String: QuestionStat] = [:]
    @State private var full: Exam?

    private var shown: Exam { full ?? exam }

    var body: some View {
        GlassCard {
            if let q = shown.questions.first {
                let correct = Grading.countsCorrect(q, in: submission)
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(correct ? Theme.green : Theme.red)
                        Text(correct ? "맞혔어요" : "아쉬워요")
                            .font(.system(size: 22, weight: .heavy))
                            .tracking(-0.6)
                            .foregroundStyle(Theme.t1)
                        Spacer(minLength: 0)
                        if let rate = stats[q.id]?.rate {
                            Text("\(Int(rate * 100))%가 맞혔어요")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(Theme.t3)
                        }
                    }

                    QuestionBodyOrLegacy(question: q)

                    VStack(alignment: .leading, spacing: 6) {
                        line("내 답", value(of: q, in: submission), Theme.t2)
                        line("정답", correctText(of: q), Theme.green)
                    }

                    if q.hasExplain {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("해설")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(Theme.t3)
                            QuestionBodyView(q.explain ?? [], fontSize: 15)
                        }
                        .padding(.top, 2)
                    }

                    Text("내일 새 문제가 올라와요")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
            }
        }
        .task {
            // 정답률은 앱에서 세지 않는다. 서버가 준 값을 그대로 쓴다.
            stats = (try? await Supa.questionStats(examId: exam.id)) ?? [:]
            // 정답이 지워진 채로 온 시험이면 다시 받아온다
            if exam.answersHidden, let fresh = try? await Supa.exam(id: exam.id) {
                full = exam.merging(answersFrom: fresh.questions)
            }
        }
    }

    private func line(_ label: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12.5, weight: .heavy))
                .foregroundStyle(Theme.t3)
                .frame(width: 38, alignment: .leading)
            Text(text)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private func value(of q: Question, in sub: Submission) -> String {
        guard let a = sub.answers[q.id], !a.isEmpty else { return "안 씀" }
        if q.type == .mc, let i = a.asInt { return "\(i + 1)번" }
        return a.asString
    }

    private func correctText(of q: Question) -> String {
        if q.type == .mc, let a = q.answer { return "\(a + 1)번" }
        if let accept = q.accept, !accept.isEmpty { return accept }
        return "—"
    }
}

// ─────────────────────────────────────────────────────────
// 달력
// ─────────────────────────────────────────────────────────

/// 이번 달에 문제가 있던 날과 내가 푼 날을 한눈에 본다.
///
/// 날을 누르면 **위에 있는 문제가 그 자리에서 바뀐다.** 새 화면을 띄우지 않는다.
/// 지난 문제를 훑어보려고 들어갔다 나왔다 하면 흐름이 끊긴다.
struct DailyCalendarCard: View {
    @EnvironmentObject var store: Store
    @Binding var month: Date
    @Binding var picked: Date?
    /// 지금 위에 떠 있는 문제. 달력에서 어느 칸인지 표시한다.
    let shownId: UUID?

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { shift(-1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.t2)
                    }
                    Spacer()
                    Text(month, format: .dateTime.year().month())
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.t1)
                    Spacer()
                    Button { shift(1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.t2)
                    }
                    .disabled(isCurrentMonth)
                    .opacity(isCurrentMonth ? 0.3 : 1)
                }

                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { d in
                        Text(d)
                            .font(.system(size: 10.5, weight: .heavy))
                            .foregroundStyle(Theme.t3)
                    }
                    ForEach(cells.indices, id: \.self) { i in
                        cell(cells[i])
                    }
                }

                Text("푼 날 \(solvedCount)일")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.t3)
            }
        }
    }

    // ── 칸 ──────────────────────────────────────────────

    private struct Cell {
        var day: Int?
        var date: Date?
        var exam: Exam?
        var solved: Bool
    }

    @ViewBuilder
    private func cell(_ c: Cell) -> some View {
        if let day = c.day {
            let here = c.exam != nil && c.exam?.id == shownId
            let content = Text("\(day)")
                .font(.system(size: 12.5, weight: .heavy))
                .foregroundStyle(c.solved ? .white : (c.exam == nil ? Theme.t3 : Theme.t1))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background {
                    if c.solved {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.buttonFill)
                    } else if c.exam != nil {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.tagBackground)
                    }
                }
                .overlay {
                    // 지금 보고 있는 날
                    if here {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.purple, lineWidth: 2)
                    }
                }

            if c.exam != nil, let date = c.date {
                Button { picked = date } label: { content }
                    .buttonStyle(PressableCardStyle())
            } else {
                content
            }
        } else {
            Color.clear.frame(height: 34)
        }
    }

    private var cells: [Cell] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let lead = calendar.component(.weekday, from: first) - 1
        var out = [Cell](repeating: Cell(day: nil, date: nil, exam: nil, solved: false),
                         count: lead)

        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: first)
            let exam = date.flatMap { store.dailyExam(on: $0) }
            let solved = exam.map { store.mySubmission(examId: $0.id) != nil } ?? false
            out.append(Cell(day: day, date: date, exam: exam, solved: solved))
        }
        return out
    }

    private var solvedCount: Int { cells.filter(\.solved).count }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func shift(_ by: Int) {
        if let next = calendar.date(byAdding: .month, value: by, to: month) {
            month = next
        }
    }
}
