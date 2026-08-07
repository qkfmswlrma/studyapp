# 작업 인수인계

마지막 정리: 2026-08-07

---

## 1. 지금 상태 요약

**Capacitor 로 감싼 앱은 다 됐고 빌드까지 확인했다.** (`capacitor` 브랜치)
**네이티브(Swift) 앱은 1단계가 거의 다 됐다.** (`main` 브랜치)
빌드가 되고, 진짜 데이터로 뜨는 화면까지 눈으로 확인했다. 아래 5번을 볼 것.

원래 요청은 "사이트를 애플 앱으로" 였는데 사이트를 감싸는 쪽으로 만들었다.
그 뒤 "기능만 가져와서 앱으로" 라는 뜻이었다는 걸 확인해서, 네이티브로 다시 만들기로 방향을 바꿨다.
아래 3번이 그 계획이다.

### 브랜치

| 브랜치 | 내용 | 상태 |
|---|---|---|
| `main` | Capacitor 앱 | 빌드 성공, 그대로 쓸 수 있음 |
| `capacitor` | `main` 과 같은 내용을 보관용으로 복사 | 네이티브로 갈아엎을 때 대비 |

네이티브를 시작하면 `main` 을 갈아엎게 되는데, `capacitor` 브랜치에 그대로 남아 있으니
언제든 되돌리거나 꺼내 쓸 수 있다.

---

## 2. 끝난 것

### 2-1. Capacitor iOS 앱

사이트를 앱 안에 넣어서 감쌌다. 화면과 기능은 사이트와 완전히 같다.

- 사이트가 CDN 에서 받아오던 React, Supabase, KaTeX, MathLive, 글꼴을 전부 앱 안에 넣었다.
  `scripts/prepare-www.js` 가 주소를 바꾸고, 바깥 주소가 하나라도 남으면 빌드를 세운다.
- 노치와 홈 표시줄을 피하도록 헤더, 본문, 창의 여백을 보정했다 (`scripts/app-native.css`).
- 화면 모드에 따라 상태 표시줄 글자색을 바꾸고, 사이트가 준비되면 시작 화면을 내린다
  (`scripts/app-native.js`).
- 앱 버전은 사이트의 `APP_VERSION` 을 따라간다 (`scripts/fix-ios.js`).
- 아이콘은 사이트 `icon-512.png` 에서 만들었다. 모서리 바깥이 투명해서 애플이 거절하므로
  안쪽을 잘라 1024 로 다시 만든다 (`scripts/make-icons.js`).

자세한 건 `README.md` 에 있다.

### 2-2. 빌드 파이프라인

**아이폰 앱은 윈도우에서 컴파일이 안 된다.** `.github/workflows/ios.yml` 이
깃허브가 빌려주는 맥(`macos-15`)에서 `xcodebuild` 를 돌린다.

두 번 다 성공했다.

- [run 31151873392](https://github.com/qkfmswlrma/studyapp/actions/runs/31151873392)
- [run 31152056333](https://github.com/qkfmswlrma/studyapp/actions/runs/31152056333)

결과물은 `suhakjilmoon-ios` 라는 이름으로 Actions 페이지에서 받는다.
`.ipa` 와 `.xcarchive` 가 들어 있다. **서명은 안 돼 있어서 아이폰에 바로는 못 넣는다.**

### 2-3. 빌드하면서 걸렸던 것 (다시 만날 문제들)

| 문제 | 원인 | 해결 |
|---|---|---|
| `cap sync` 가 맥에서 죽음 | 깃허브가 Node 24 를 강제 | 워크플로에서 Node 22 로 고정 |
| 맥에서 스위프트 문법 오류 | 윈도우 `cap sync` 가 `Package.swift` 에 역슬래시 경로를 씀 | `scripts/fix-ios.js` 가 매번 고침 |
| 액션 로그가 안 보임 | 공개 저장소여도 로그는 로그인해야 보임 | `scripts/ci-run.sh` 가 실패 내용을 주석으로 남김. 주석은 API 로 누구나 읽음 |
| 아이콘 거절 | 원본 모서리 바깥이 투명 | 안쪽을 잘라내서 정사각형으로 |

마지막 것이 특히 중요하다. 빌드가 왜 깨졌는지 알아내는 유일한 방법이었다.

```
https://api.github.com/repos/qkfmswlrma/studyapp/check-runs/<job_id>/annotations
```

### 2-4. 아직 안 된 것 (Capacitor 쪽)

- **서명.** 애플 개발자 계정이 있어야 한다. 계정이 생기면 Xcode 에서
  `ios/App/App.xcodeproj` 열고 Signing & Capabilities 에서 팀만 고르면 된다.
  번들 아이디는 `app.mathroom.suhakjilmoon`.
- **실기기 확인.** 시뮬레이터에서도 아직 안 띄워봤다. 컴파일만 확인했다.
  노치 여백 보정이 실제로 맞는지, 수식이 제대로 그려지는지는 눈으로 봐야 안다.
- **앱스토어 심사.** 사이트를 감싸기만 한 앱은 반려될 수 있다 (지침 4.2).
  네이티브로 가면 이 문제는 사라진다.

---

## 3. 이어서 할 것 — 네이티브 전환

### 3-0. 먼저 알아야 할 것

**Supabase 는 손댈 필요가 없다.** SQL 한 줄도 실행하지 않는다.

- 같은 주소, 같은 anon 키로 붙는다. 회원과 기록이 그대로다.
- 사이트에서 가입한 사람이 같은 아이디와 비번으로 앱에 로그인한다.
- 사이트와 앱이 동시에 살아 있어도 된다.
- **RLS 와 `is_admin()`, `is_root()` 가 서버에서 판정하므로 권한이 저절로 따라온다.**
  앱을 새로 짜도 칼럼은 회원만, 남의 시험 수정은 root 만 하는 규칙이 그대로 걸린다.

### 3-1. 기술 선택 (정해둔 것)

| 항목 | 무엇 | 왜 |
|---|---|---|
| 화면 | SwiftUI | |
| DB | `supabase-swift` (SPM) | 세션을 Keychain 에 저장해서 로그인이 유지된다 |
| 수식 표시 | `SwiftMath` (SPM) | KaTeX 를 대신한다. 네이티브로 그린다 |
| 수식 입력 | **미정** | MathLive 를 대신할 게 마땅치 않다. 3단계에서 다시 판단 |
| 프로젝트 파일 | XcodeGen (`project.yml`) | 윈도우에서 `.xcodeproj` 를 손으로 못 고친다. 파일을 추가해도 설정을 안 건드려도 된다 |

XcodeGen 은 맥에서 `brew install xcodegen` 후 `xcodegen generate` 로 돈다.
CI 에도 그 단계를 넣어야 한다.

**확인 방법.** 윈도우에서는 SwiftUI 를 실행할 수 없다. 대신 CI 에서
시뮬레이터를 띄우고 화면을 찍어 올리면 눈으로 볼 수 있다.

```bash
xcrun simctl boot "iPhone 16"
xcrun simctl install booted App.app
xcrun simctl launch booted app.mathroom.suhakjilmoon
xcrun simctl io booted screenshot shot.png
```

이 단계를 CI 에 넣는 것을 네이티브 작업의 **맨 처음에** 해야 한다.
안 그러면 화면을 못 보고 만들게 된다.

### 3-2. 단계

**1단계 — 뼈대와 핵심**

- 로그인, 회원가입 (아이디 → `아이디@mathroom.app` 로 바꿔서 이메일 로그인)
- 홈, 탭 이동
- 공지사항 목록과 글 (비회원도 봄)
- 칼럼 목록과 글 (회원만. 비회원에게는 자물쇠 화면. "글이 0개" 처럼 보이면 안 됨)
- 시험: 레벨테스트 목록, 오늘의 문제, 응시, 제출, 채점 결과, 정답률
- 내 기록, 오답노트
- 계정: 비번 변경, 로그아웃, 탈퇴

**2단계** — 모의고사 기록과 통계와 타이머, 게임과 랭킹

**3단계** — 관리자: 출제, 채점, 회원 관리
(수식 입력기를 어떻게 할지 여기서 결정해야 한다)

### 3-3. 옮길 때 반드시 지킬 것

사이트를 읽어서 알아낸 것들이다. **이걸 어기면 숫자가 사이트와 달라진다.**

**시험은 `exams` 가 아니라 `exams_view` 를 읽는다.**
아직 안 푼 사람에게는 서버가 정답과 해설을 지우고 준다.
표를 직접 읽으면 정답이 딸려 와서 앱에서 다 보인다.

**채점 규칙** (`_source.html` 555~605줄, `exam_question_stats` 와 같아야 한다)

```
객관식(mc)   : answers[q.id] == q.answer            (숫자 index 비교)
주관식(short): accept 가 비어 있지 않고
               answers[q.id].trim() == accept.trim()
사람이 매긴 점수(manual_scores)가 있으면 그게 우선.
0 이상 q.points 이하로 자른다.
```

**정답률은 앱에서 계산하지 않는다.**
`exam_question_stats(exam_id)` 와 `exam_stats_all()` 을 부른다.
학생은 남의 제출을 못 읽어서 앱에서 계산하면 자기 것만 반영된다.
**회원과 비회원을 합쳐서** 낸다. 목록, 응시 화면, 채점 결과가 같은 숫자를 보여야 한다.

**글번호를 앱이 해석하지 않는다.**
`110001` 같은 6자리를 자릿수로 쪼개 뜻을 읽으면 안 된다.
`no` 와 `prev_nos` 에서 찾기만 한다. 분류가 바뀌면 새 번호를 받고
옛 번호는 `prev_nos` 에 남아 옛 링크가 계속 열린다.

**root 를 화면에 드러내지 않는다.**
"root 만 가능합니다" 같은 안내를 띄우지 말고 그 화면 자체가 안 보이게 한다.
회원 관리 탭은 root 에게만 보인다. 활동 기록에서 회원 관리 항목은 걸러낸다.

### 3-4. 사이트에서 찾아야 할 위치

| 무엇 | 어디 |
|---|---|
| Supabase 주소와 anon 키 | `_source.html` 66~68줄 |
| `EMAIL_DOMAIN = "mathroom.app"` | `_source.html` 68줄 |
| 채점 함수들 | `_source.html` 555~605줄 |
| 테마 색 (CSS 변수) | `_source.html` 5859~5864줄 |
| 화면 컴포넌트 58개 | `_source.html` 에서 `grep -n "^function [A-Z]"` |
| DB 전체 | `../수학/_schema.sql` (37KB, 아직 커밋 안 된 파일) |

### 3-5. DB 표와 함수 목록

**표**
`profiles` `columns` `exams` `submissions` `guest_submissions`
`column_reads` `exam_reads` `audit_log` `speed_scores` `exam_records` `exam_categories`

`columns` 에서 `category = 'notice'` 인 것이 공지사항이다. 칼럼과 공지가 같은 표를 쓴다.

**뷰**
`exams_view` — 정답을 지우고 주는 시험 목록. 앱은 이걸 읽는다.

**함수**

| 함수 | 쓰는 곳 |
|---|---|
| `exam_question_stats(exam_id)` | 문항별 정답률 |
| `exam_stats_all()` | 시험별 합계, 목록에서 한 번에 |
| `submit_guest_attempt(exam_id, answers)` | 비회원 제출. 하루 한 번 제한 |
| `speed_ranking(limit)` `my_speed_rank()` `submit_speed_score(...)` | 게임 랭킹 |
| `post_preview(no)` | 링크 미리보기 |
| `delete_my_account()` | 탈퇴 |
| `admin_delete_user(username)` `admin_reset_password(username)` | root 전용 |
| `is_admin()` `is_root()` | 정책 안에서 판정 |

### 3-6. 크기 참고

- `_source.html` 8,209줄
- 화면 컴포넌트 58개
- 수식을 쓰는 곳 12군데

한 번에 다 옮기는 건 무리다. 1단계부터 순서대로 간다.

---

## 5. 네이티브 1단계 — 지금까지 짠 것

`main` 브랜치가 이제 SwiftUI 앱이다. Capacitor 는 `capacitor` 브랜치로 옮겼다.

### 짜놓은 파일

```
project.yml                     XcodeGen 설정. 맥에서 xcodegen generate 하면 .xcodeproj 가 나온다
Sources/
  App/SuhakApp.swift            @main, 탭 구성, 제목줄, 시작 화면
  Core/
    Supa.swift                  Supabase 붙이기, 읽기와 쓰기
    Models.swift                Profile Post Exam Question Submission 그리고 정답률
    JSONValue.swift             답이 숫자이기도 글자이기도 해서 필요한 그릇
    Grading.swift               채점 규칙. 사이트와 서버 함수에 맞췄다
    Store.swift                 앱 상태 한곳에. 화면마다 따로 불러오면 숫자가 달라진다
    Theme.swift                 색, 유리, 단추
  UI/MathText.swift             SwiftMath 로 수식 그리기, 본문 조각 배치
  Features/
    AuthSheet.swift             로그인, 회원가입
    Posts.swift                 홈, 칼럼과 공지 목록과 글
    Exams.swift                 시험 목록, 응시, 채점 결과
    RecordsAccount.swift        내 기록, 오답노트, 계정
```

### 확인된 것

- 맥에서 컴파일된다
- XcodeGen 으로 프로젝트가 만들어진다
- supabase-swift 2.54.1 과 SwiftMath 1.7.3 이 붙는다

**화면을 눈으로 봤다.** 의심스럽다고 적어뒀던 것이 전부 정상이었다.

- 진짜 Supabase 에 붙는다. 공지와 시험, 글쓴이와 날짜가 그대로 뜬다
- 날짜를 읽는다. `2026년 7월 25일` 로 나온다
- `exams_view` 의 questions(jsonb)를 읽는다. 문항 수와 배점, 보기가 다 나온다
- 정답률이 서버 값 그대로 나온다. 목록과 응시 화면이 같은 숫자다
- SwiftMath 가 문장 중간의 수식을 그린다. 어두운 화면에서 색도 따라온다
- 칼럼은 비회원에게 자물쇠 화면이 뜬다. "글이 0개" 로 보이지 않는다

### 화면 보는 법

CI 가 시뮬레이터를 켜고 찍어 `screenshots` 가지에 올린다. 로그인 없이 받아진다.

```
https://raw.githubusercontent.com/qkfmswlrma/studyapp/screenshots/01-home.png
```

시뮬레이터에는 손가락이 없어서 목록을 눌러 들어갈 수 없다.
그래서 깊은 화면은 앱이 실행 인자를 보고 스스로 연다 (`Sources/App/Launch.swift`).

```bash
xcrun simctl launch <기기> app.mathroom.suhakjilmoon --tab 3 --open exam-take
```

`--open` 에 넣을 수 있는 값은 `post` `exam-list` `exam-take` `exam-today` 다.
화면을 새로 만들면 여기에도 하나 추가해야 눈으로 볼 수 있다.

### 찍어보고 고친 것

빌드만으로는 안 나오고 화면을 봐야 나왔던 것들이다.

| 무엇 | 왜 |
|---|---|
| `0.4` 점짜리 문항이 "0점" 으로 보였다 | 배점을 `Int` 로 잘랐다. 실제 배점에 소수가 있다 |
| 수식이 글자 위로 떠서 위첨자 같았다 | 줄 안에서 위를 맞추고 있었다. 기준선을 맞춰야 한다 |
| 오답노트가 다 맞히면 빈 화면이었다 | 푼 시험이 있는지로 갈라서 안내가 안 떴다 |

**점수는 `Int` 로 자르지 않는다.** `Double.scoreText` 를 쓴다 (`Grading.swift`).

### 아직 확인 못 한 것

**로그인한 화면을 못 봤다.** CI 는 비회원으로만 띄운다.
내 기록, 오답노트, 채점 결과, 계정은 아직 눈으로 못 봤다.
확인하려면 시험용 계정을 만들어 CI 비밀값에 넣고 `--open` 에 길을 하나 더 내야 한다.

**실기기에서 못 돌려봤다.** 노치 여백과 수식 크기는 실제 기기에서 봐야 안다.

### 남은 것

**1단계 마무리**
- 글번호로 여는 길 (`no` 와 `prev_nos` 로 찾기).
  `matches(no:)` 는 만들어뒀지만 아직 아무도 부르지 않는다.
  카톡으로 받은 링크를 앱이 열려면 애플 개발자 계정이 있어야 한다

**2단계** — 모의고사 기록과 통계와 타이머, 게임과 랭킹

**3단계** — 관리자: 출제, 채점, 회원 관리
수식 입력기(MathLive 대신 쓸 것)를 여기서 정해야 한다

### 유리에 대해

iOS 26 은 `glassEffect` 를, 그 아래는 Material 을 쓴다.
`compiler(>=6.2)` 로 감싸서 Xcode 26 이 없는 곳에서도 컴파일된다.

- 유리는 뒤에 볼 게 있어야 유리다. `AppBackground` 가 색덩어리를 깔아준다
- 가까이 붙은 유리는 `GlassGroup` 으로 묶어야 서로 녹아 붙는다
- 탭 막대와 제목줄은 iOS 26 이 스스로 그린다. 손대면 옛날 모양이 된다
- 가장 중요한 단추는 유리로 하지 않는다. 꽉 찬 색으로 둔다

---

## 4. 사이트 저장소는 건드리지 않았다

`../수학` 은 읽기만 했다. 커밋도 푸시도 하지 않았다.
마지막 커밋은 그대로 `4faecd9 v2.16.1` 이다.

네이티브로 가더라도 사이트 코드에 앱 전용 분기를 넣지 않는다.
사이트와 앱이 서로를 갉아먹는다.
