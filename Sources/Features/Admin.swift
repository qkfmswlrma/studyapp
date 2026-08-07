import SwiftUI

// ─────────────────────────────────────────────────────────
// 관리자
//
// **root 라는 말이 화면 어디에도 나오면 안 된다.**
// "root 만 가능합니다" 같은 안내를 띄우지 않고, 아예 그 화면이 안 보이게 한다.
// 회원 관리 칸 자체를 root 에게만 보여주고, 활동 기록에서도 회원 관리 항목을 걸러낸다.
// ─────────────────────────────────────────────────────────

struct AdminScreen: View {
    @EnvironmentObject var store: Store

    private enum Section: String, CaseIterable {
        case dash = "현황"
        case log = "활동 기록"
        case members = "회원"
    }

    @State private var section: Section = .dash
    @State private var users: [Profile] = []
    @State private var submissions: [Submission] = []
    @State private var log: [AuditEntry] = []
    @State private var loading = true

    /// 회원 칸은 root 에게만 보인다
    private var sections: [Section] {
        store.isRoot ? Section.allCases : [.dash, .log]
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    picker.padding(.horizontal, 20).padding(.top, 8)

                    if loading {
                        EmptyNote(text: "불러오는 중…").padding(.horizontal, 20)
                    } else {
                        switch section {
                        case .dash:    dashboard
                        case .log:     logList
                        case .members: memberList
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("관리자")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var picker: some View {
        HStack(spacing: 6) {
            ForEach(sections, id: \.self) { s in
                let on = s == section
                Button(s.rawValue) {
                    withAnimation(.easeOut(duration: 0.2)) { section = s }
                }
                .font(.system(size: 13.5, weight: .heavy))
                .foregroundStyle(on ? .white : Theme.t2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    if on {
                        RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.brand)
                    }
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Theme.surface.opacity(0.5)))
    }

    // ── 현황 ────────────────────────────────────────────

    private var dashboard: some View {
        VStack(spacing: 12) {
            let columns = [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)]
            LazyVGrid(columns: columns, spacing: 11) {
                tile("회원", users.count)
                tile("칼럼과 공지", store.posts.count)
                tile("시험", store.exams.count)
                tile("제출", submissions.count)
            }

            // 채점을 기다리는 제출
            let pending = submissions.filter { !$0.graded }
            if !pending.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("채점 기다리는 제출 \(pending.count)건")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Theme.t1)
                        Text("시험 화면에서 제출을 눌러 점수를 매길 수 있어요")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.t2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func tile(_ label: String, _ value: Int) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 12.5, weight: .heavy))
                    .foregroundStyle(Theme.t3)
                Text("\(value)")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.t1)
            }
        }
    }

    // ── 활동 기록 ───────────────────────────────────────

    private var logList: some View {
        VStack(spacing: 10) {
            // 회원 관리 항목은 root 에게만 보인다
            let visible = log.filter { store.isRoot || !$0.isMemberAction }
            if visible.isEmpty {
                EmptyNote(text: "아직 기록이 없어요")
            } else {
                ForEach(visible) { entry in
                    GlassCard(padding: 15, radius: 20) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 7) {
                                TagPill(text: entry.action)
                                Spacer(minLength: 0)
                                if let date = entry.createdAt {
                                    Text(date, format: .dateTime.month().day().hour().minute())
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(Theme.t3)
                                }
                            }
                            Text(entry.target.isEmpty ? "—" : entry.target)
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundStyle(Theme.t1)
                            Text(entry.actor.isEmpty ? "알 수 없음" : entry.actor)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.t3)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // ── 회원 ────────────────────────────────────────────

    private var memberList: some View {
        VStack(spacing: 10) {
            ForEach(users) { user in
                MemberRow(user: user, onChanged: { await load() })
            }
        }
        .padding(.horizontal, 20)
    }

    private func load() async {
        loading = true
        users = (try? await Supa.allProfiles()) ?? []
        submissions = (try? await Supa.allSubmissions()) ?? []
        log = (try? await Supa.auditLog()) ?? []
        loading = false
    }
}

/// 회원 한 줄. root 에게만 보이는 화면 안에 있다.
struct MemberRow: View {
    @EnvironmentObject var store: Store
    let user: Profile
    let onChanged: () async -> Void

    @State private var confirmDelete = false
    @State private var confirmReset = false
    @State private var note: String?

    var body: some View {
        GlassCard(padding: 16, radius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(user.username)
                        .font(.system(size: 15.5, weight: .heavy))
                        .foregroundStyle(Theme.t1)
                    if user.isAdmin { TagPill(text: "관리자") }
                    Spacer(minLength: 0)
                    if let date = user.createdAt {
                        Text(date, format: .dateTime.year().month().day())
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.t3)
                    }
                }

                if !user.kakaoId.isEmpty {
                    Text("채팅방 \(user.kakaoId)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.t3)
                }

                if let note {
                    Text(note)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.green)
                }

                // 자기 자신은 손대지 못하게 둔다
                if user.id != store.profile?.id {
                    HStack(spacing: 8) {
                        Button(user.isAdmin ? "관리자 해제" : "관리자 지정") {
                            Task { await toggleAdmin() }
                        }
                        .buttonStyle(GlassButtonStyle(radius: 11))

                        Button("비번 초기화") { confirmReset = true }
                            .buttonStyle(GlassButtonStyle(radius: 11))

                        Spacer(minLength: 0)

                        Button("삭제") { confirmDelete = true }
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Theme.red)
                    }
                }
            }
        }
        .alert("'\(user.username)' 회원을 삭제할까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) { Task { await remove() } }
            Button("그만두기", role: .cancel) {}
        } message: {
            Text("쓴 글과 기록이 함께 지워지고 되돌릴 수 없어요.")
        }
        .alert("비밀번호를 초기화할까요?", isPresented: $confirmReset) {
            Button("초기화", role: .destructive) { Task { await reset() } }
            Button("그만두기", role: .cancel) {}
        } message: {
            Text("'\(user.username)' 회원의 비밀번호가 0000 으로 바뀌어요.")
        }
    }

    private func toggleAdmin() async {
        let on = !user.isAdmin
        do {
            try await Supa.setAdmin(username: user.username, on: on)
            await record(on ? "관리자 지정" : "관리자 해제")
            await onChanged()
        } catch {
            note = store.message(for: error)
        }
    }

    private func remove() async {
        do {
            try await Supa.deleteUser(username: user.username)
            await record("회원 삭제")
            await onChanged()
        } catch {
            note = store.message(for: error)
        }
    }

    private func reset() async {
        do {
            try await Supa.resetPassword(username: user.username)
            await record("비밀번호 초기화")
            note = "비밀번호를 0000 으로 바꿨어요"
        } catch {
            note = store.message(for: error)
        }
    }

    private func record(_ action: String) async {
        guard let me = store.profile else { return }
        try? await Supa.log(action: action, target: user.username,
                            actor: me.username, actorId: me.id)
    }
}
