import SwiftUI

// ─────────────────────────────────────────────────────────
// 스피드 연산 (무한 모드, 콤보 지수 배율)
//
// **점수 공식을 바꾸면 안 된다.** 서버가 같은 식으로 검산해서,
// 정답 수로 낼 수 있는 이론상 최대 점수를 넘으면 위조로 보고 거절한다.
//   한 문제 맞힐 때마다  round(10 × 1.15^콤보)
// ─────────────────────────────────────────────────────────

/// 한 문제
struct SpeedQuestion {
    let text: String
    let answer: Int
    let options: [Int]
}

/// 문제를 만든다. 콤보가 오를수록 자릿수가 늘고 나눗셈이 섞인다.
enum SpeedMaker {
    /// 자릿수 사다리. ○ 는 사칙연산 아무거나.
    static let stages: [[Int]] = [
        [1, 1],       // 한자리 ○ 한자리
        [1, 2],       // 한자리 ○ 두자리
        [2, 2],       // 두자리 ○ 두자리
        [2, 1, 1],    // 두자리 ○ 한자리 ○ 한자리
        [2, 2, 1],    // 두자리 ○ 두자리 ○ 한자리
        [2, 3],       // 두자리 ○ 세자리
        [2, 2, 2],    // 두자리 ○ 두자리 ○ 두자리
    ]
    /// 단계별 등장 콤보 기준. 어려운 단계는 한참 뒤에 나온다.
    static let thresholds = [0, 9, 18, 27, 36, 45, 54]

    static func make(combo: Int) -> SpeedQuestion {
        var stage = 0
        for (i, t) in thresholds.enumerated() where combo >= t { stage = i }
        let digits = stages[min(stage, stages.count - 1)]

        var nums: [Int] = []
        var ops: [String] = []
        var answer = 0
        var guardCount = 0

        repeat {
            guardCount += 1
            nums = [number(of: digits[0])]
            ops = []
            for i in 1..<digits.count {
                // 나눗셈은 후반부터. 연속 나눗셈은 정수 보장이 깨져서 뺀다.
                var pool = stage >= 3 ? ["+", "−", "×", "÷"] : ["+", "−", "×"]
                if ops.last == "÷" { pool.removeAll { $0 == "÷" } }
                let op = pool.randomElement() ?? "+"
                ops.append(op)
                if op == "÷" {
                    // 직전 항을 (이번 항 × 몫)으로 다시 맞춰 정수 나눗셈을 보장한다
                    let divisor = number(of: digits[i])
                    let quotient = Int.random(in: 2...9)
                    nums[i - 1] = divisor * quotient
                    nums.append(divisor)
                } else {
                    nums.append(number(of: digits[i]))
                }
            }
            answer = evaluate(nums, ops)
        } while answer < 0 && guardCount < 40

        if answer < 0 {
            nums = [number(of: digits[0]), number(of: digits[digits.count - 1])]
            ops = ["+"]
            answer = nums[0] + nums[1]
        }

        var text = String(nums[0])
        for (i, op) in ops.enumerated() { text += " \(op) \(nums[i + 1])" }

        return SpeedQuestion(text: text, answer: answer, options: options(around: answer))
    }

    private static func number(of digits: Int) -> Int {
        digits <= 1
            ? Int.random(in: 2...9)
            : Int.random(in: Int(pow(10.0, Double(digits - 1)))...(Int(pow(10.0, Double(digits))) - 1))
    }

    /// 곱하기와 나누기를 먼저 접는다. 나눗셈은 떨어지게 만들어서 정수가 보장된다.
    private static func evaluate(_ nums: [Int], _ ops: [String]) -> Int {
        var n = nums, o = ops
        var i = 0
        while i < o.count {
            if o[i] == "×" || o[i] == "÷" {
                if o[i] == "÷" && n[i + 1] == 0 { return -1 }
                let v = o[i] == "×" ? n[i] * n[i + 1] : n[i] / n[i + 1]
                n.replaceSubrange(i...(i + 1), with: [v])
                o.remove(at: i)
            } else {
                i += 1
            }
        }
        var r = n[0]
        for (i, op) in o.enumerated() {
            if op == "+" { r += n[i + 1] } else { r -= n[i + 1] }
        }
        return r
    }

    /// 보기는 정답과 그 언저리 오답 셋
    private static func options(around answer: Int) -> [Int] {
        var set: Set<Int> = [answer]
        var guardCount = 0
        while set.count < 4 && guardCount < 80 {
            guardCount += 1
            let spread = max(2, Int((Double(abs(answer)) * 0.08).rounded()) + 1)
            var cand = answer + Int.random(in: -spread...spread)
            if cand == answer || cand < 0 {
                cand = answer + (Bool.random() ? 1 : -1) * Int.random(in: 1...(spread + 2))
            }
            if cand != answer && cand >= 0 { set.insert(cand) }
        }
        return set.shuffled()
    }
}

// ─────────────────────────────────────────────────────────
// 화면
// ─────────────────────────────────────────────────────────

struct GameScreen: View {
    @EnvironmentObject var store: Store
    /// 홈에서 밀고 들어온 경우에는 이미 남의 탐색 더미 안이다
    var embedded = false

    private enum Phase { case ready, playing, over }

    @State private var phase: Phase = .ready
    @State private var question: SpeedQuestion?
    @State private var score = 0
    @State private var combo = 0
    @State private var comboMax = 0
    @State private var correctCount = 0
    @State private var timeLeft: Double = 40
    @State private var startedAt = Date()
    @State private var picked: Int?
    @State private var wasCorrect = false

    @State private var ranking: [SpeedRank] = []
    @State private var myRank: MySpeedRank?
    @State private var loadingRank = true
    @State private var saveNote: String?

    private let start: Double = 40
    private let bonus: Double = 2
    private let penalty: Double = 5

    /// 랭킹에 올리려면 채팅방 닉네임이 있어야 한다. 서버도 없으면 거절한다.
    private var nickname: String {
        (store.profile?.kakaoId ?? "").trimmingCharacters(in: .whitespaces)
    }
    private var canRank: Bool { store.loggedIn && !nickname.isEmpty }

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        if embedded {
            content.navigationBarTitleDisplayMode(.inline)
        } else {
            NavigationStack { content }
        }
    }

    private var content: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle(text: "스피드 연산")
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    switch phase {
                    case .ready:   readyCard
                    case .playing: playingCard
                    case .over:    overCard
                    }

                    RankingCard(ranking: ranking, myRank: myRank,
                                loading: loadingRank, nickname: nickname,
                                canRank: canRank, loggedIn: store.loggedIn)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
        }
        .task { await loadRanking() }
        .onReceive(tick) { _ in step() }
    }

    // ── 화면 조각 ───────────────────────────────────────

    private var readyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("40초로 시작해요")
                    .font(.system(size: 19, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.t1)
                Text("맞히면 2초를 벌고 틀리면 5초를 잃어요.\n연달아 맞힐수록 점수가 크게 붙어요.")
                    .font(.system(size: 14, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(Theme.t2)

                if !canRank {
                    Text(store.loggedIn
                         ? "채팅방 닉네임을 정하면 랭킹에 오를 수 있어요"
                         : "로그인하면 랭킹에 오를 수 있어요")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.purple)
                }

                Button("시작하기") { begin() }
                    .buttonStyle(BrandButtonStyle())
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
    }

    private var playingCard: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(spacing: 14) {
                    HStack {
                        Text("\(score)")
                            .font(.system(size: 30, weight: .heavy))
                            .tracking(-1)
                            .foregroundStyle(Theme.t1)
                        Spacer()
                        Text(combo > 0 ? "×\(combo) · \(multiplierText)" : "콤보 없어요")
                            .font(.system(size: 13.5, weight: .heavy))
                            .foregroundStyle(combo >= 5 ? Theme.pink : Theme.t3)
                    }

                    // 남은 시간
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.hairline)
                            Capsule()
                                .fill(timeLeft < 8 ? AnyShapeStyle(Theme.red)
                                                   : AnyShapeStyle(Theme.brand))
                                .frame(width: geo.size.width * timeFraction)
                        }
                    }
                    .frame(height: 8)

                    Text(String(format: "%.1f초", max(0, timeLeft)))
                        .font(.system(size: 12.5, weight: .heavy))
                        .foregroundStyle(timeLeft < 8 ? Theme.red : Theme.t3)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(question?.text ?? "")
                        .font(.system(size: 30, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(Theme.t1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }

            if let question {
                let columns = [GridItem(.flexible(), spacing: 10),
                               GridItem(.flexible(), spacing: 10)]
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(question.options, id: \.self) { option in
                        Button { choose(option) } label: {
                            Text("\(option)")
                                .font(.system(size: 19, weight: .heavy))
                                .foregroundStyle(colorFor(option))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Theme.surface))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(borderFor(option), lineWidth: 1.5))
                        }
                        .buttonStyle(PressableCardStyle())
                        .disabled(picked != nil)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var overCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                Text("끝났어요")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.t3)
                Text("\(score)")
                    .font(.system(size: 44, weight: .heavy))
                    .tracking(-1.5)
                    .foregroundStyle(Theme.t1)
                Text("\(correctCount)문제를 맞혔고 최고 콤보는 \(comboMax)예요")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.t2)

                if let saveNote {
                    Text(saveNote)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                        .multilineTextAlignment(.center)
                }

                Button("다시 하기") { begin() }
                    .buttonStyle(BrandButtonStyle())
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
    }

    // ── 움직임 ──────────────────────────────────────────

    private var timeFraction: Double {
        max(0, min(1, timeLeft / start))
    }

    private var multiplierText: String {
        String(format: "×%.1f", pow(1.15, Double(combo)))
    }

    private func colorFor(_ option: Int) -> Color {
        guard let picked, picked == option else { return Theme.t1 }
        return wasCorrect ? Theme.green : Theme.red
    }

    private func borderFor(_ option: Int) -> Color {
        guard let picked, picked == option else { return Theme.hairline }
        return (wasCorrect ? Theme.green : Theme.red).opacity(0.7)
    }

    private func begin() {
        score = 0
        combo = 0
        comboMax = 0
        correctCount = 0
        timeLeft = start
        picked = nil
        saveNote = nil
        startedAt = Date()
        question = SpeedMaker.make(combo: 0)
        phase = .playing
    }

    private func step() {
        guard phase == .playing else { return }
        timeLeft = max(0, timeLeft - 0.1)
        if timeLeft <= 0 { finish() }
    }

    private func choose(_ value: Int) {
        guard phase == .playing, let q = question, picked == nil else { return }
        let correct = value == q.answer
        picked = value
        wasCorrect = correct

        if correct {
            let next = combo + 1
            // 서버가 검산하는 식과 같아야 한다
            score += Int((10 * pow(1.15, Double(next))).rounded())
            combo = next
            comboMax = max(comboMax, next)
            correctCount += 1
            timeLeft += bonus
        } else {
            combo = 0
            timeLeft = max(0, timeLeft - penalty)
        }

        let carried = correct ? combo : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            picked = nil
            if phase == .playing && timeLeft > 0 {
                question = SpeedMaker.make(combo: carried)
            } else if timeLeft <= 0 {
                finish()
            }
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        phase = .over
        picked = nil
        guard canRank else {
            saveNote = store.loggedIn
                ? "채팅방 닉네임을 정하면 점수가 랭킹에 올라가요"
                : "로그인하면 점수가 랭킹에 올라가요"
            return
        }
        let elapsed = Date().timeIntervalSince(startedAt)
        Task {
            do {
                try await Supa.submitSpeedScore(score: score, correct: correctCount,
                                                combo: comboMax, seconds: elapsed)
                saveNote = "점수를 올렸어요"
                await loadRanking()
            } catch {
                saveNote = store.message(for: error)
            }
        }
    }

    private func loadRanking() async {
        loadingRank = true
        ranking = (try? await Supa.speedRanking()) ?? []
        myRank = store.loggedIn ? (try? await Supa.mySpeedRank()) ?? nil : nil
        loadingRank = false
    }
}

/// 랭킹 카드. 게임 화면과 랭킹 화면이 같이 쓴다.
struct RankingCard: View {
    let ranking: [SpeedRank]
    let myRank: MySpeedRank?
    let loading: Bool
    let nickname: String
    let canRank: Bool
    let loggedIn: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("🏆 랭킹")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.t1)

                if let myRank {
                    HStack {
                        Text("내 순위")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.purple)
                        Spacer()
                        Text("\(myRank.myRank)위 · \(myRank.bestScore)점")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.t1)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(Theme.tagBackground, in: Capsule())
                }

                if !loggedIn {
                    Text("로그인하면 랭킹에 참여할 수 있어요")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                }

                if loading {
                    Text("불러오는 중…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                } else if ranking.isEmpty {
                    Text("아직 랭킹이 없어요. 첫 주인공이 되어보세요")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(ranking.enumerated()), id: \.offset) { i, row in
                            let mine = canRank && row.nickname == nickname
                            HStack(spacing: 12) {
                                Text("\(i + 1)")
                                    .font(.system(size: 12.5, weight: .heavy))
                                    .foregroundStyle(i < 3 ? Theme.purple : Theme.t3)
                                    .frame(width: 22, alignment: .leading)
                                Text(row.nickname)
                                    .font(.system(size: 14, weight: mine ? .heavy : .semibold))
                                    .foregroundStyle(Theme.t1)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text("\(row.bestScore)")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(mine ? Theme.purple : Theme.t2)
                            }
                            .padding(.vertical, 9)
                            if i < ranking.count - 1 { Divider().opacity(0.35) }
                        }
                    }
                }
            }
        }
    }
}
