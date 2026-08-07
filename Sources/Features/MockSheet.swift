import SwiftUI

/// 모의고사 성적을 적거나 고친다.
///
/// 시험 이름은 분류와 연도(또는 회차)를 합쳐 한 줄로 저장한다.
/// 평가원과 교육청은 몇 년도 시험인지를 앞에, 내가 만든 건 회차를 뒤에 붙인다.
struct MockRecordSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let record: ExamRecord?
    let subject: String

    @State private var parts = ExamNameParts()
    @State private var examDate = Date()
    @State private var subjectKey = MockSubject.first
    @State private var detail = ""
    @State private var rawScore = ""
    @State private var stdScore = ""
    @State private var percentile = ""
    @State private var grade = ""
    @State private var cuts: [String] = Array(repeating: "", count: 8)
    @State private var wrongNos = ""
    @State private var memo = ""

    @State private var newCategory = ""
    @State private var busy = false
    @State private var error: String?

    private var info: MockSubject { MockSubject.of(subjectKey) }

    /// 고를 수 있는 분류. 기본 분류에 내가 만든 것을 잇는다.
    private var categories: [String] {
        let mine = store.examCategories
            .filter { $0.subject == nil || $0.subject == subjectKey }
            .map(\.name)
        return BASE_CATEGORIES + mine
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        categoryCard
                        basicsCard
                        scoreCard
                        if info.hasPercentile { cutsCard }
                        wrongCard

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
            .navigationTitle(record == nil ? "성적 적기" : "성적 고치기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }.foregroundStyle(Theme.t2)
                }
            }
        }
        .onAppear(perform: fill)
    }

    // ── 칸 ──────────────────────────────────────────────

    private var categoryCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                label("어떤 시험인가요")

                Picker("분류", selection: $parts.cat) {
                    Text("고르기").tag("")
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Theme.purple)

                if isBaseCategory(parts.cat) {
                    // 2026년에 2024년 기출을 풀 수 있으니 응시일과 따로 받는다
                    Picker("연도", selection: $parts.year) {
                        Text("연도").tag("")
                        ForEach(examYears, id: \.self) { Text($0 + "년").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.purple)
                } else if !parts.cat.isEmpty {
                    field("회차", text: $parts.round, keyboard: .numberPad)
                }

                HStack(spacing: 8) {
                    TextField("분류 추가", text: $newCategory)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(12)
                        .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 11))
                    Button("추가") { Task { await addCategory() } }
                        .buttonStyle(GlassButtonStyle(radius: 11))
                        .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var basicsCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                label("언제 어떤 과목을")
                DatePicker("응시일", selection: $examDate, displayedComponents: .date)
                    .font(.system(size: 14, weight: .semibold))
                    .tint(Theme.purple)

                Picker("과목", selection: $subjectKey) {
                    ForEach(MockSubject.all) { s in
                        Text(TamguNames.label(s.key)).tag(s.key)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.purple)

                field("세부 과목", text: $detail)
            }
        }
    }

    private var scoreCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                label("점수")
                field("원점수 (최대 \(info.max))", text: $rawScore, keyboard: .decimalPad)
                if info.hasPercentile {
                    field("표준점수", text: $stdScore, keyboard: .numberPad)
                    field("백분위", text: $percentile, keyboard: .numberPad)
                }
                field("등급 1~9", text: $grade, keyboard: .numberPad)
            }
        }
    }

    private var cutsCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                label("등급컷 원점수")
                Text("아는 것만 적어도 돼요. 표준점수와 백분위를 예상해서 보여줘요")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.t3)

                ForEach(0..<8, id: \.self) { i in
                    HStack(spacing: 10) {
                        Text("\(i + 1)등급")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.t2)
                            .frame(width: 50, alignment: .leading)
                        TextField("", text: $cuts[i])
                            .keyboardType(.numberPad)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(10)
                            .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var wrongCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                label("틀린 문항과 메모")
                field("틀린 문항 번호. 쉼표로 나눠요", text: $wrongNos, keyboard: .numbersAndPunctuation)
                field("메모", text: $memo)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13.5, weight: .heavy))
            .foregroundStyle(Theme.t3)
    }

    private func field(_ placeholder: String, text: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .font(.system(size: 14, weight: .semibold))
            .padding(12)
            .background(Theme.hairline, in: RoundedRectangle(cornerRadius: 11))
    }

    // ── 채우기와 저장 ───────────────────────────────────

    private func fill() {
        subjectKey = record?.subject ?? subject
        guard let r = record else {
            parts.cat = BASE_CATEGORIES.first ?? ""
            return
        }
        parts = parseExamName(r.examName, myNames: store.examCategories.map(\.name))
        if let d = Self.dateFormatter.date(from: r.examDate) { examDate = d }
        detail = r.detail
        rawScore = r.rawScore.map { $0.scoreText } ?? ""
        stdScore = r.stdScore.map { String(Int($0)) } ?? ""
        percentile = r.percentile.map { String(Int($0)) } ?? ""
        grade = r.grade.map(String.init) ?? ""
        memo = r.memo
        wrongNos = r.wrongNos.map(String.init).joined(separator: ", ")
        if let gc = r.gradeCuts {
            for i in 0..<min(8, gc.count) {
                cuts[i] = gc[i].map(String.init) ?? ""
            }
        }
    }

    private func addCategory() async {
        let name = newCategory.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let me = store.profile else { return }
        do {
            try await Supa.addExamCategory(name: name, subject: nil, userId: me.id)
            await store.loadMock()
            parts.cat = name
            parts.round = suggestRound(store.examRecords, cat: name)
            newCategory = ""
        } catch {
            // catch 가 error 라는 이름을 가려서 self 를 붙여야 상태에 닿는다
            self.error = store.message(for: error)
        }
    }

    private func save() async {
        error = nil
        guard let me = store.profile else { return }

        let name = composeExamName(parts)
        guard !name.isEmpty else {
            error = "어떤 시험인지 골라주세요."
            return
        }
        let gradeValue = Int(grade.trimmingCharacters(in: .whitespaces))
        if let g = gradeValue, g < 1 || g > 9 {
            error = "등급은 1부터 9까지예요."
            return
        }

        // 하나라도 적었으면 등급컷을 통째로 보낸다. 빈 칸은 빈 채로 간다.
        let cutValues: [Int?]? = cuts.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            ? cuts.map { Int($0.trimmingCharacters(in: .whitespaces)) }
            : nil

        let wrongList = wrongNos
            .split(whereSeparator: { ", ，、".contains($0) })
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        let input = ExamRecordInput(
            user_id: me.id,
            exam_name: name,
            exam_date: Self.dateFormatter.string(from: examDate),
            subject: subjectKey,
            detail: detail.trimmingCharacters(in: .whitespaces),
            raw_score: Double(rawScore.trimmingCharacters(in: .whitespaces)),
            std_score: Double(stdScore.trimmingCharacters(in: .whitespaces)),
            percentile: Double(percentile.trimmingCharacters(in: .whitespaces)),
            grade: gradeValue,
            wrong_nos: wrongList,
            grade_cuts: cutValues,
            duration_sec: record?.durationSec,
            memo: memo.trimmingCharacters(in: .whitespaces))

        busy = true
        defer { busy = false }
        do {
            if let r = record {
                try await Supa.updateExamRecord(id: r.id, input)
            } else {
                _ = try await Supa.addExamRecord(input)
            }
            await store.loadMock()
            dismiss()
        } catch {
            self.error = store.message(for: error)
        }
    }

    /// 응시일은 날짜만 저장한다. 시각이 붙으면 시간대에 따라 하루가 밀린다.
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
