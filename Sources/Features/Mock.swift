import SwiftUI

// ─────────────────────────────────────────────────────────
// 모의고사
//
// 성적을 적어두고 흐름을 본다. 전부 본인 것만 보인다.
// 등급컷만 아는 사설 모의고사도 백분위와 표준점수를 예상해서 보여준다.
// 그 계산은 MockScoring 에 있고 사이트와 같은 값이 나와야 한다.
// ─────────────────────────────────────────────────────────

struct MockScreen: View {
    @EnvironmentObject var store: Store

    @State private var subject = MockSubject.first
    @State private var editing: ExamRecord?
    @State private var adding = false
    @State private var confirmDelete: ExamRecord?

    private var records: [ExamRecord] {
        store.examRecords.filter { $0.subject == subject }
    }

    /// 기록이 있는 과목만 고르개에 남긴다. 일곱 개를 다 늘어놓으면 고르기 힘들다.
    private var usedSubjects: [MockSubject] {
        let used = MockSubject.all.filter { s in
            store.examRecords.contains { $0.subject == s.key }
        }
        return used.isEmpty ? [MockSubject.of(MockSubject.first)] : used
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if !store.loggedIn {
                    LoginNeeded(what: "모의고사")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                ScreenTitle(text: "모의고사")
                                Button {
                                    adding = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 15, weight: .heavy))
                                        .foregroundStyle(.white)
                                        .frame(width: 38, height: 38)
                                        .background(Theme.brand, in: Circle())
                                        .shadow(color: Theme.purple.opacity(0.35), radius: 10, y: 5)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                            MockTimerCard()
                                .padding(.horizontal, 20)

                            subjectPicker
                                .padding(.horizontal, 20)

                            if records.isEmpty {
                                EmptyNote(text: "아직 적어둔 성적이 없어요")
                                    .padding(.horizontal, 20)
                            } else {
                                MockTrendCard(records: records)
                                    .padding(.horizontal, 20)

                                ForEach(records) { record in
                                    Button { editing = record } label: {
                                        MockRecordRow(record: record)
                                    }
                                    .buttonStyle(PressableCardStyle())
                                    .padding(.horizontal, 20)
                                    .contextMenu {
                                        Button("지우기", role: .destructive) {
                                            confirmDelete = record
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .refreshable { await store.loadMock() }
                }
            }
        }
        .sheet(isPresented: $adding) {
            MockRecordSheet(record: nil, subject: subject)
        }
        .sheet(item: $editing) { record in
            MockRecordSheet(record: record, subject: record.subject)
        }
        .alert("이 기록을 지울까요?", isPresented: .constant(confirmDelete != nil)) {
            Button("지우기", role: .destructive) {
                if let r = confirmDelete { Task { await store.deleteExamRecord(r) } }
                confirmDelete = nil
            }
            Button("그만두기", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("되돌릴 수 없어요.")
        }
        .task { await store.loadMock() }
    }

    private var subjectPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(usedSubjects) { s in
                    let on = s.key == subject
                    Button(TamguNames.label(s.key)) {
                        withAnimation(.easeOut(duration: 0.2)) { subject = s.key }
                    }
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundStyle(on ? .white : Theme.t2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background {
                        if on {
                            Capsule().fill(Theme.brand)
                                .shadow(color: Theme.purple.opacity(0.3), radius: 9, y: 4)
                        } else {
                            Capsule().fill(Theme.surface.opacity(0.7))
                        }
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// 기록 한 줄
// ─────────────────────────────────────────────────────────

struct MockRecordRow: View {
    let record: ExamRecord

    private var percentile: (value: Double?, guess: Bool) { MockScoring.percentile(of: record) }
    private var stdScore: (value: Double?, guess: Bool) { MockScoring.stdScore(of: record) }

    var body: some View {
        GlassCard(padding: 16, radius: 22) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Text(record.examName.isEmpty ? "이름 없는 시험" : record.examName)
                        .font(.system(size: 16, weight: .bold))
                        .tracking(-0.25)
                        .foregroundStyle(Theme.t1)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if let g = record.grade {
                        Text("\(g)등급")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(gradeColor(g), in: Capsule())
                    }
                }

                HStack(spacing: 14) {
                    if let raw = record.rawScore {
                        stat("원점수", raw.scoreText, guess: false)
                    }
                    if let s = stdScore.value {
                        stat("표준점수", String(Int(s)), guess: stdScore.guess)
                    }
                    if let p = percentile.value {
                        stat("백분위", String(Int(p)), guess: percentile.guess)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    Text(record.examDate)
                    if !record.detail.isEmpty {
                        Text("·")
                        Text(record.detail)
                    }
                    if !record.wrongNos.isEmpty {
                        Text("·")
                        Text("틀린 문항 \(record.wrongNos.count)개")
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.t3)
            }
        }
    }

    private func stat(_ label: String, _ value: String, guess: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 10.5, weight: .heavy))
                    .foregroundStyle(Theme.t3)
                // 등급컷으로 잡은 값이라는 표시. 적어둔 값과 섞이면 안 된다.
                if guess {
                    Text("예상")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Theme.purple)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Theme.tagBackground, in: Capsule())
                }
            }
            Text(value)
                .font(.system(size: 15.5, weight: .heavy))
                .foregroundStyle(Theme.t1)
        }
    }

    private func gradeColor(_ g: Int) -> Color {
        switch g {
        case 1, 2: return Theme.green
        case 3, 4: return Theme.purple
        case 5, 6: return Color(hex: 0xF5A623)
        default:   return Theme.red
        }
    }
}

// ─────────────────────────────────────────────────────────
// 점수 흐름
// ─────────────────────────────────────────────────────────

/// 최근 성적이 오르는지 내리는지만 보여준다.
/// 등급은 낮을수록 좋아서 위아래를 뒤집어 그린다.
struct MockTrendCard: View {
    let records: [ExamRecord]

    /// 오래된 것부터. 목록은 최신순이라 뒤집는다.
    private var points: [(label: String, grade: Int)] {
        records.reversed().compactMap { r in
            guard let g = r.grade else { return nil }
            return (String(r.examDate.suffix(5)), g)
        }
        .suffix(8)
        .map { $0 }
    }

    var body: some View {
        if points.count >= 2 {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("등급 흐름")
                        .font(.system(size: 14.5, weight: .heavy))
                        .foregroundStyle(Theme.t1)

                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                            VStack(spacing: 5) {
                                Text("\(p.grade)")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(Theme.t2)
                                // 1등급이 가장 높이 오도록 9에서 뺀다
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Theme.brand)
                                    .frame(height: CGFloat(10 - p.grade) * 9)
                                Text(p.label)
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(Theme.t3)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 118, alignment: .bottom)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// 시간 재기
// ─────────────────────────────────────────────────────────

/// 과목을 고르고 실제 시험 시간만큼 잰다.
/// 앱을 끄면 멈춘다. 화면에 붙어 있는 동안만 도는 단순한 시계다.
struct MockTimerCard: View {
    @State private var subject = MockSubject.first
    @State private var endsAt: Date?
    @State private var left: Int = MockSubject.of(MockSubject.first).minutes * 60

    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private var running: Bool { endsAt != nil }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("시간 재기")
                        .font(.system(size: 14.5, weight: .heavy))
                        .foregroundStyle(Theme.t1)
                    Spacer()
                    Text(MockSubject.of(subject).at)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                }

                Text(clock)
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(left <= 300 && running ? Theme.red : Theme.t1)
                    .frame(maxWidth: .infinity)

                if !running {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(MockSubject.all) { s in
                                let on = s.key == subject
                                Button(TamguNames.label(s.key)) {
                                    subject = s.key
                                    left = s.minutes * 60
                                }
                                .font(.system(size: 12.5, weight: .heavy))
                                .foregroundStyle(on ? .white : Theme.t2)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background {
                                    if on { Capsule().fill(Theme.brand) }
                                    else { Capsule().fill(Theme.surface.opacity(0.7)) }
                                }
                            }
                        }
                    }
                }

                Button(running ? "그만두기" : "\(MockSubject.of(subject).minutes)분 재기") {
                    if running {
                        endsAt = nil
                        left = MockSubject.of(subject).minutes * 60
                    } else {
                        let total = MockSubject.of(subject).minutes * 60
                        left = total
                        endsAt = Date().addingTimeInterval(Double(total))
                    }
                }
                .buttonStyle(BrandButtonStyle())
            }
        }
        .onReceive(tick) { _ in
            guard let endsAt else { return }
            let rest = Int(endsAt.timeIntervalSinceNow.rounded())
            if rest <= 0 {
                left = 0
                self.endsAt = nil
            } else {
                left = rest
            }
        }
    }

    private var clock: String {
        let m = left / 60, s = left % 60
        return String(format: "%02d:%02d", m, s)
    }
}
