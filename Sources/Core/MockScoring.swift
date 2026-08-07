import Foundation

/// 등급컷으로 백분위와 표준점수를 잡는다.
///
/// **사이트(_source.html 7004~7120줄)와 같은 값이 나와야 한다.**
/// 사이트에서 3등급이던 기록이 앱에서 2등급으로 보이면 안 된다.
enum MockScoring {

    /// 등급별 누적 비율. 1등급컷에 딱 걸치면 상위 4% 이므로 백분위 96 이다.
    static let cutPercentiles: [Double] = [96, 89, 77, 60, 40, 23, 11, 4]

    /// 등급컷마다 대응하는 z 값. 상위 4% 자리의 z 는 1.751 이다.
    static let cutZ: [Double] = [1.751, 1.227, 0.739, 0.253, -0.253, -0.739, -1.227, -1.751]

    /// 국어와 수학은 평균 100 표준편차 20, 나머지는 평균 50 표준편차 10
    static func stdScale(_ key: String) -> (m: Double, sd: Double) {
        (key == "korean" || key == "math") ? (100, 20) : (50, 10)
    }

    // ── 백분위 ──────────────────────────────────────────
    //
    // 사설 모의고사는 표본이 적어 백분위를 못 내고 예상 등급컷만 주는 곳이 많다.
    // 등급별 누적 비율은 정해져 있으니, 등급컷 표와 내 원점수가 있으면
    // 내가 어느 등급 어디쯤인지 비례로 잡을 수 있다.

    static func estimatePercentile(cuts: [Int?]?, rawScore: Double?, subject: String) -> Int? {
        let info = MockSubject.of(subject)
        guard info.hasPercentile, let cuts, let raw = rawScore else { return nil }

        // 빈 칸은 건너뛴다. 아는 등급컷만 적어도 잡아준다.
        var points: [(s: Double, p: Double)] = []
        for (i, c) in cuts.enumerated() where i < cutPercentiles.count {
            guard let c else { continue }
            points.append((Double(c), cutPercentiles[i]))
        }
        guard !points.isEmpty else { return nil }
        points.sort { $0.s < $1.s }

        // 0점은 백분위 0, 만점은 100 으로 양끝을 잡아두고 그 사이를 잇는다
        var all: [(s: Double, p: Double)] = [(0, 0)]
        for q in points where q.s > all[all.count - 1].s { all.append(q) }
        if Double(info.max) > all[all.count - 1].s { all.append((Double(info.max), 100)) }

        if raw <= all[0].s { return Int(all[0].p) }
        if raw >= all[all.count - 1].s { return Int(all[all.count - 1].p) }

        guard let v = monotoneAt(xs: all.map(\.s), ys: all.map(\.p), x: raw) else { return nil }
        return Int(Swift.max(0, Swift.min(100, v.rounded())))
    }

    /// 적어둔 백분위가 있으면 그걸 쓰고, 없으면 등급컷으로 잡은 값을 쓴다.
    /// `guess` 가 참이면 화면에서 예상값이라고 밝혀야 한다.
    static func percentile(of r: ExamRecord) -> (value: Double?, guess: Bool) {
        if let p = r.percentile { return (p, false) }
        guard let g = estimatePercentile(cuts: r.gradeCuts, rawScore: r.rawScore,
                                         subject: r.subject)
        else { return (nil, false) }
        return (Double(g), true)
    }

    // ── 표준점수 ────────────────────────────────────────
    //
    // (z, 원점수) 짝을 여러 개 놓고 직선을 맞추면 평균과 표준편차가 나온다.
    // 성적이 정규분포를 이룬다고 가정하는 것이라 만점자가 몰리면 어긋난다.
    // 그래서 화면에서는 반드시 예상값이라고 밝힌다.

    static func estimateStdScore(cuts: [Int?]?, rawScore: Double?, subject: String) -> Int? {
        guard MockSubject.of(subject).hasPercentile,
              let cuts, let raw = rawScore else { return nil }

        var zs: [Double] = [], ss: [Double] = []
        for (i, c) in cuts.enumerated() where i < cutZ.count {
            guard let c else { continue }
            zs.append(cutZ[i])
            ss.append(Double(c))
        }
        guard zs.count >= 2 else { return nil }   // 점이 둘은 있어야 직선을 그린다

        let zbar = zs.reduce(0, +) / Double(zs.count)
        let sbar = ss.reduce(0, +) / Double(ss.count)
        var num = 0.0, den = 0.0
        for i in zs.indices {
            num += (zs[i] - zbar) * (ss[i] - sbar)
            den += (zs[i] - zbar) * (zs[i] - zbar)
        }
        guard den != 0 else { return nil }

        let sd = num / den                // 원점수 기준 표준편차
        guard sd.isFinite, sd > 0 else { return nil }
        let avg = sbar - sd * zbar        // 원점수 기준 평균

        let scale = stdScale(subject)
        let out = (scale.m + scale.sd * ((raw - avg) / sd)).rounded()
        guard out.isFinite else { return nil }
        return Int(Swift.max(0, out))
    }

    static func stdScore(of r: ExamRecord) -> (value: Double?, guess: Bool) {
        if let s = r.stdScore { return (s, false) }
        guard let g = estimateStdScore(cuts: r.gradeCuts, rawScore: r.rawScore,
                                       subject: r.subject)
        else { return (nil, false) }
        return (Double(g), true)
    }

    // ── 보간 ────────────────────────────────────────────

    /// 점들을 매끄럽게 잇되 오르내리지 않게 (단조 3차 보간).
    /// 직선으로 이으면 등급컷마다 꺾여서 실제보다 어긋난다.
    static func monotoneAt(xs: [Double], ys: [Double], x: Double) -> Double? {
        let n = xs.count
        guard n >= 2 else { return nil }
        if n == 2 {
            let t = xs[1] == xs[0] ? 1 : (x - xs[0]) / (xs[1] - xs[0])
            return ys[0] + t * (ys[1] - ys[0])
        }

        var d: [Double] = [], m: [Double] = []
        for i in 0..<(n - 1) { d.append((ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])) }
        m.append(d[0])
        for i in 1..<(n - 1) { m.append(d[i - 1] * d[i] <= 0 ? 0 : (d[i - 1] + d[i]) / 2) }
        m.append(d[n - 2])

        for i in 0..<(n - 1) {
            if d[i] == 0 { m[i] = 0; m[i + 1] = 0; continue }
            let a = m[i] / d[i], b = m[i + 1] / d[i], s = a * a + b * b
            if s > 9 {
                let t = 3 / s.squareRoot()
                m[i] = t * a * d[i]
                m[i + 1] = t * b * d[i]
            }
        }

        for i in 0..<(n - 1) where x >= xs[i] && x <= xs[i + 1] {
            let h = xs[i + 1] - xs[i], t = (x - xs[i]) / h
            let h00 = 2*t*t*t - 3*t*t + 1
            let h10 = t*t*t - 2*t*t + t
            let h01 = -2*t*t*t + 3*t*t
            let h11 = t*t*t - t*t
            return h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]
        }
        return nil
    }
}
