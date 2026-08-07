import SwiftUI

// ─────────────────────────────────────────────────────────
// 출제
//
// 쓸 때는 exams 표에 직접 넣는다. exams_view 는 읽기 전용이라 못 쓴다.
// 글번호는 서버 트리거가 붙이므로 앱이 만들지 않는다.
// ─────────────────────────────────────────────────────────

struct ExamEditorSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let exam: Exam?
    let defaultType: ExamType

    @State private var title = ""
    @State private var examType: ExamType = .level
    @State private var scheduled = false
    @State private var publishAt = Date()
    @State private var questions: [Question] = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        basicsCard

                        ForEach($questions) { $question in
                            QuestionEditorCard(question: $question,
                                               index: (questions.firstIndex(where: { $0.id == question.id }) ?? 0) + 1,
                                               onDelete: {
                                questions.removeAll { $0.id == question.id }
                            })
                        }

                        Button {
                            questions.append(Question.blank())
                        } label: {
                            Label("문항 추가", systemImage: "plus")
                                .font(.system(size: 14.5, weight: .heavy))
                                .foregroundStyle(Theme.purple)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Theme.tagBackground,
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        if let error {
                            Text(error)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Theme.red)
                        }

                        Button(busy ? "저장 중…" : "저장하기") { Task { await save() } }
                            .buttonStyle(BrandButtonStyle())
                            .disabled(busy)
                            .opacity(busy ? 0.6 : 1)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(exam == nil ? "시험 내기" : "시험 고치기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }.foregroundStyle(Theme.t2)
                }
            }
        }
        .onAppear(perform: fill)
    }

    private var basicsCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("시험 제목", text: $title)
                    .font(.system(size: 15, weight: .bold))
                    .padding(12)
                    .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 11))

                Picker("종류", selection: $examType) {
                    Text("레벨테스트").tag(ExamType.level)
                    Text("오늘의 문제").tag(ExamType.today)
                }
                .pickerStyle(.segmented)

                Toggle("공개 날짜 정하기", isOn: $scheduled)
                    .font(.system(size: 14, weight: .bold))
                    .tint(Theme.purple)

                if scheduled {
                    DatePicker("공개", selection: $publishAt, displayedComponents: .date)
                        .font(.system(size: 14, weight: .semibold))
                        .tint(Theme.purple)
                    Text("이 날이 되기 전에는 학생에게 보이지 않아요")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                }
            }
        }
    }

    private func fill() {
        guard let e = exam else {
            examType = defaultType
            questions = [Question.blank()]
            return
        }
        title = e.title
        examType = e.examType
        questions = e.questions
        if let at = e.publishAt {
            scheduled = true
            publishAt = at
        }
    }

    private func save() async {
        error = nil
        guard let me = store.profile else { return }

        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { error = "제목을 적어주세요."; return }
        guard !questions.isEmpty else { error = "문항을 하나는 넣어주세요."; return }

        // 주관식 정답이 비어 있으면 자동 채점이 안 된다. 사이트도 여기서 막는다.
        for (i, q) in questions.enumerated() {
            if q.type == .short, (q.accept ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                error = "\(i + 1)번 주관식의 정답을 적어주세요."
                return
            }
            if q.type == .mc, q.options.count < 2 {
                error = "\(i + 1)번 객관식의 보기를 두 개 이상 넣어주세요."
                return
            }
        }

        // 공개 날짜는 그날 0시로 맞춘다. 시각까지 받으면 학생마다 보이는 때가 갈린다.
        let publish = scheduled
            ? Calendar.current.startOfDay(for: publishAt)
            : nil

        busy = true
        defer { busy = false }
        do {
            if let e = exam {
                try await Supa.updateExam(id: e.id, ExamPatch(
                    title: name, questions: questions,
                    exam_type: examType.rawValue, publish_at: publish))
                try? await Supa.log(action: "시험 수정", target: name,
                                    actor: me.username, actorId: me.id)
            } else {
                try await Supa.saveExam(ExamInput(
                    title: name, questions: questions,
                    author: me.username, author_id: me.id,
                    exam_type: examType.rawValue, publish_at: publish))
                try? await Supa.log(action: "시험 출제", target: name,
                                    actor: me.username, actorId: me.id)
            }
            await store.reload()
            dismiss()
        } catch {
            self.error = store.message(for: error)
        }
    }
}

// ─────────────────────────────────────────────────────────
// 문항 하나
// ─────────────────────────────────────────────────────────

struct QuestionEditorCard: View {
    @Binding var question: Question
    let index: Int
    let onDelete: () -> Void

    @State private var pointsText = ""

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(index)번")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.t1)
                    Spacer()
                    Button("지우기", action: onDelete)
                        .font(.system(size: 12.5, weight: .heavy))
                        .foregroundStyle(Theme.red)
                }

                Picker("종류", selection: $question.type) {
                    Text("객관식").tag(QuestionType.mc)
                    Text("주관식").tag(QuestionType.short)
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    Text("배점")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.t3)
                    TextField("0", text: $pointsText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 14, weight: .bold))
                        .padding(10)
                        .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 10))
                        .onChange(of: pointsText) { _ in
                            question.points = Double(pointsText) ?? 0
                        }
                }

                BodyEditor(title: "문제 본문", blocks: $question.body)

                if question.type == .mc {
                    optionEditor
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("정답")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.t3)
                        TextField("정확히 이 글자와 같아야 맞아요",
                                  text: Binding(get: { question.accept ?? "" },
                                                set: { question.accept = $0 }))
                            .font(.system(size: 14, weight: .semibold))
                            .padding(11)
                            .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 11))
                    }
                }

                BodyEditor(title: "해설", blocks: Binding(
                    get: { question.explain ?? [] },
                    set: { question.explain = $0.isEmpty ? nil : $0 }))
            }
        }
        .onAppear { pointsText = question.points.scoreText }
    }

    private var optionEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("보기")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.t3)

            ForEach(question.options.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    // 동그라미 숫자로 몇 번인지 보인다
                    Button {
                        question.answer = i
                    } label: {
                        Image(systemName: question.answer == i
                              ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 19))
                            .foregroundStyle(question.answer == i ? Theme.green : Theme.t3)
                    }

                    TextField("보기 \(i + 1)", text: Binding(
                        get: { i < question.options.count ? question.options[i] : "" },
                        set: { if i < question.options.count { question.options[i] = $0 } }))
                        .font(.system(size: 14, weight: .semibold))
                        .padding(10)
                        .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 10))

                    Button {
                        question.options.remove(at: i)
                        if let a = question.answer, a >= question.options.count {
                            question.answer = question.options.isEmpty ? nil : question.options.count - 1
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.t3)
                    }
                }
            }

            Button("보기 추가") { question.options.append("") }
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.purple)

            Text("동그라미를 눌러 정답을 고르세요")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.t3)
        }
    }
}

// ─────────────────────────────────────────────────────────
// 본문 조각 편집
//
// 본문은 글과 수식이 번갈아 놓인 조각들이다.
// 조건 박스는 시작과 끝 표시로 감싼 사이가 박스 안에 들어간다.
// ─────────────────────────────────────────────────────────

struct BodyEditor: View {
    let title: String
    @Binding var blocks: [BodyBlock]

    @State private var mathIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.t3)

            ForEach(blocks.indices, id: \.self) { i in
                row(at: i)
            }

            HStack(spacing: 7) {
                addButton("글", "text.alignleft") { blocks.append(.text("")) }
                addButton("수식", "function") {
                    blocks.append(.math(""))
                    mathIndex = blocks.count - 1
                }
                addButton("조건 박스", "square.dashed") {
                    blocks.append(.boxStart)
                    blocks.append(.text(""))
                    blocks.append(.boxEnd)
                }
            }
        }
        .sheet(item: Binding(
            get: { mathIndex.map { MathEditTarget(index: $0) } },
            set: { mathIndex = $0?.index })) { target in
            MathInputSheet(initial: latex(at: target.index)) { value in
                if target.index < blocks.count { blocks[target.index] = .math(value) }
            }
        }
    }

    private struct MathEditTarget: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private func latex(at i: Int) -> String {
        guard i < blocks.count, case .math(let l) = blocks[i] else { return "" }
        return l
    }

    @ViewBuilder
    private func row(at i: Int) -> some View {
        HStack(spacing: 8) {
            switch blocks[i] {
            case .text(let value):
                TextField("글", text: Binding(
                    get: { value },
                    set: { if i < blocks.count { blocks[i] = .text($0) } }),
                          axis: .vertical)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1...6)
                    .padding(10)
                    .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 10))

            case .math(let latex):
                Button { mathIndex = i } label: {
                    HStack {
                        if latex.isEmpty {
                            Text("수식을 넣어주세요")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.t3)
                        } else {
                            MathLabel(latex: latex, fontSize: 16)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.tagBackground, in: RoundedRectangle(cornerRadius: 10))
                }

            case .boxStart:
                marker("조건 박스 시작")
            case .boxEnd:
                marker("조건 박스 끝")
            }

            Button {
                if i < blocks.count { blocks.remove(at: i) }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.t3)
            }
        }
    }

    private func marker(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(Theme.t2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8).padding(.horizontal, 10)
            .background(Theme.surface.opacity(0.6),
                        in: RoundedRectangle(cornerRadius: 10))
    }

    private func addButton(_ label: String, _ icon: String,
                           _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Label(label, systemImage: icon)
                .font(.system(size: 12.5, weight: .heavy))
                .foregroundStyle(Theme.purple)
                .padding(.horizontal, 11).padding(.vertical, 9)
                .background(Theme.tagBackground, in: Capsule())
        }
    }
}

extension Question {
    /// 새 문항. id 는 앱이 붙인다. 채점이 이 값으로 답을 찾는다.
    static func blank() -> Question {
        let json = """
        {"id":"\(UUID().uuidString.prefix(8))","type":"mc","points":0,
         "body":[],"options":["",""]}
        """
        // 스스로 만든 JSON 이라 실패할 일이 없지만, 실패해도 앱이 죽지 않게 둔다.
        if let data = json.data(using: .utf8),
           let q = try? JSONDecoder().decode(Question.self, from: data) {
            return q
        }
        return (try? JSONDecoder().decode(
            Question.self,
            from: Data(#"{"id":"q","type":"mc","points":0}"#.utf8)))!
    }
}
