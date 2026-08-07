import Foundation

/// 앱을 켤 때 어느 화면을 열지 실행 인자로 고른다.
///
/// 윈도우에서는 SwiftUI 를 띄워볼 수 없다. 확인할 방법은 CI 에서 시뮬레이터를 켜고
/// 찍어 올리는 것뿐인데, 시뮬레이터는 손가락이 없어서 목록을 눌러 들어갈 수가 없다.
/// 그래서 깊은 화면은 앱이 스스로 열어줘야 찍을 수 있다.
///
///     xcrun simctl launch <기기> <앱> --tab 3 --open exam-take
///
/// 사람이 쓰는 기능이 아니라 화면을 확인하려고 둔 문이다.
/// 인자를 안 주면 평소처럼 홈으로 켜지므로 실제 사용자에게는 없는 것과 같다.
enum Launch {

    /// 켤 때 고를 탭. 0 홈, 1 칼럼, 2 시험, 3 모의고사, 4 기록
    static var tab: Int { Int(value("--tab") ?? "") ?? 0 }

    /// 켜자마자 밀고 들어갈 화면
    ///
    /// | 값 | 어느 탭에서 | 열리는 화면 |
    /// |---|---|---|
    /// | `notice` | 홈 | 공지 목록 |
    /// | `post` | 홈 | 공지 첫 글 |
    /// | `game` | 홈 | 스피드 연산 |
    /// | `exam-list` | 시험 | 레벨테스트 목록 |
    /// | `exam-take` | 시험 | 레벨테스트 첫 시험 응시 |
    /// | `exam-today` | 시험 | 오늘의 문제 목록 |
    static var open: String? { value("--open") }

    private static func value(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
