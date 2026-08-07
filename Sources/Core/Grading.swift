import Foundation

/// 채점 규칙.
///
/// **사이트(_source.html 555~605줄)와 서버 함수(exam_question_stats)가 쓰는 규칙과
/// 글자 하나까지 같아야 한다.** 여기가 어긋나면 같은 답인데 사이트에서는 맞고
/// 앱에서는 틀리는 일이 생긴다.
enum Grading {

    /// 주관식은 앞뒤 공백을 떼고 글자로 견준다.
    /// 정답이 비어 있는 문제는 자동으로는 못 맞힌다. 사람이 매겨야 한다.
    static func isShortCorrect(_ q: Question, _ answer: JSONValue?) -> Bool {
        let key = (q.accept ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        return (answer?.asString ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == key
    }

    static func isCorrect(_ q: Question, _ answer: JSONValue?) -> Bool {
        switch q.type {
        case .mc:    return answer?.asInt != nil && answer?.asInt == q.answer
        case .short: return isShortCorrect(q, answer)
        }
    }

    /// 한 문항의 점수. 사람이 매긴 점수가 있으면 그게 우선이고,
    /// 0 이상 배점 이하로 자른다.
    static func score(_ q: Question, in sub: Submission) -> Double {
        if let ov = sub.manualScores[q.id], !ov.isEmpty, let v = ov.asDouble {
            return max(0, min(q.points, v))
        }
        return isCorrect(q, sub.answers[q.id]) ? q.points : 0
    }

    static func total(_ exam: Exam, _ sub: Submission) -> Double {
        exam.questions.reduce(0) { $0 + score($1, in: sub) }
    }

    /// 제출 직후 화면에 보여줄 자동 채점 점수.
    static func auto(_ exam: Exam, _ answers: [String: JSONValue]) -> Double {
        exam.questions.reduce(0) { sum, q in
            sum + (isCorrect(q, answers[q.id]) ? q.points : 0)
        }
    }

    /// 맞춘 것으로 볼지. 사람이 만점을 줬으면 맞은 것으로 센다.
    static func countsCorrect(_ q: Question, in sub: Submission) -> Bool {
        if q.type == .mc { return isCorrect(q, sub.answers[q.id]) }
        if let ov = sub.manualScores[q.id], !ov.isEmpty, let v = ov.asDouble {
            return q.points > 0 && v >= q.points
        }
        return isShortCorrect(q, sub.answers[q.id])
    }
}
