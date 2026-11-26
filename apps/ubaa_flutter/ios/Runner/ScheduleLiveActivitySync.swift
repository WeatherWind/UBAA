import ActivityKit
import Foundation

/// 把已经发布的「接下来」分段交给系统实时活动。
/// 发布和回到前台时对齐；不读学校，也不注册推送。
@available(iOS 17.0, *)
enum ScheduleLiveActivitySync {
    private static var generation = 0

    static func resync(store: ScheduleWidgetStore = .shared) {
        Task { @MainActor in
            generation += 1
            let ticket = generation
            let steps = runnable(ScheduleLivePlan.steps(now: Date(), snapshot: store.readState().snapshot))
            await apply(steps, ticket: ticket)
        }
    }

    /// iOS 26 才能预约下一段的开始时间。更早的系统只对齐当前这一张。
    private static func runnable(_ steps: [ScheduleLiveStep]) -> [ScheduleLiveStep] {
        steps.filter { step in
            if step.start == nil { return true }
            if #available(iOS 26.0, *) { return true }
            return false
        }
    }

    @MainActor
    private static func apply(_ steps: [ScheduleLiveStep], ticket: Int) async {
        guard ticket == generation else { return }
        let existing = Activity<ScheduleLiveAttributes>.activities.filter(isCurrent)
        if matches(existing, steps) { return }
        for activity in existing {
            guard ticket == generation else { return }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for step in steps {
            guard ticket == generation else { return }
            let content = ActivityContent(state: step.face, staleDate: step.until)
            do {
                if let start = step.start {
                    guard #available(iOS 26.0, *) else { continue }
                    let alert = AlertConfiguration(
                        title: LocalizedStringResource(stringLiteral: step.face.alertTitle),
                        body: LocalizedStringResource(stringLiteral: step.face.alertBody),
                        sound: .default
                    )
                    _ = try Activity.request(
                        attributes: ScheduleLiveAttributes(),
                        content: content,
                        pushType: nil,
                        style: .standard,
                        alertConfiguration: alert,
                        start: start
                    )
                } else {
                    _ = try Activity.request(
                        attributes: ScheduleLiveAttributes(),
                        content: content,
                        pushType: nil
                    )
                }
            } catch {
                // 名额用尽或系统拒绝时，桌面组件仍按原时间线更新。
            }
        }
    }

    private static func isCurrent(_ activity: Activity<ScheduleLiveAttributes>) -> Bool {
        switch activity.activityState {
        case .active, .stale:
            return true
        default:
            if #available(iOS 26.0, *), activity.activityState == .pending { return true }
            return false
        }
    }

    private static func matches(
        _ activities: [Activity<ScheduleLiveAttributes>], _ steps: [ScheduleLiveStep]
    ) -> Bool {
        guard activities.count == steps.count else { return false }
        let current = activities.map { signature($0.content.state, until: $0.content.staleDate) }.sorted()
        let desired = steps.map { signature($0.face, until: $0.until) }.sorted()
        return current == desired
    }

    private static func signature(_ face: ScheduleLiveFace, until: Date?) -> String {
        "\(face.desktopKey)\u{1}\(face.classStart?.timeIntervalSince1970 ?? 0)\u{1}\(face.sectionEnd?.timeIntervalSince1970 ?? 0)\u{1}\(face.periodEnd?.timeIntervalSince1970 ?? 0)\u{1}\(face.countdownLabel ?? "")\u{1}\(face.countdownEnd?.timeIntervalSince1970 ?? 0)\u{1}\(until?.timeIntervalSince1970 ?? 0)"
    }
}
