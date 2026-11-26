import ActivityKit
import Foundation

/// 通知中心实时活动要显示的一张「接下来」卡片。
/// 时间行与 Android 桌面组件相同：进行中写成「至」加结束时间，其余沿用快照的 `timeText`。
struct ScheduleLiveFace: Codable, Hashable {
    var timeText: String
    var ongoing: Bool
    var tag: String?
    var title: String
    var place: String?
    var extraCount: Int
    var secondaryText: String?
    var secondaryExam: Bool
    var countdownLabel: String?
    var countdownEnd: Date?
    var link: String?
    var isPrivate: Bool

    /// 桌面上会换成另一张卡的文字。一小时内才出现的倒计时不单独换卡。
    var desktopKey: String {
        [
            timeText, ongoing ? "1" : "0", tag ?? "", title, place ?? "",
            String(extraCount), secondaryText ?? "", secondaryExam ? "1" : "0",
        ].joined(separator: "\u{1}")
    }

    var alertTitle: String { ongoing ? "进行中" : "接下来" }

    var alertBody: String {
        [timeText, place, isPrivate ? nil : title]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// 一张卡片的显示窗口。`start == nil` 表示立刻显示。
struct ScheduleLiveStep: Equatable {
    var face: ScheduleLiveFace
    var start: Date?
    var until: Date
}

enum ScheduleLivePlan {
    /// 当前这一张，再加上下一次课表面貌变化。
    /// 实时活动不能按课表自己换内容；多排几张会在锁屏上叠在一起。
    static let maxSteps = 2
    /// 系统最多让一张实时活动活跃约 8 小时，窗口不超过这个长度。
    static let maxDuration: TimeInterval = 8 * 60 * 60

    static func steps(now: Date, snapshot: WidgetSnapshot?) -> [ScheduleLiveStep] {
        guard let snapshot, let horizon = snapshot.horizonEnd, now < horizon,
              let segments = snapshot.upNext, !segments.isEmpty else { return [] }
        let hasCurrent = segments.contains { $0.from <= now }
        var index = hasCurrent ? segments.lastIndex { $0.from <= now }! : 0
        var skippedLeading = false
        var steps: [ScheduleLiveStep] = []
        while index < segments.count, steps.count < maxSteps {
            guard let face = makeFace(segments[index]) else {
                if !hasCurrent, steps.isEmpty { skippedLeading = true }
                index += 1
                continue
            }
            var endIndex = index
            while endIndex + 1 < segments.count,
                  let next = makeFace(segments[endIndex + 1]),
                  next.desktopKey == face.desktopKey {
                endIndex += 1
            }
            let promote = steps.isEmpty && !hasCurrent && !skippedLeading
            let start = promote ? now : max(segments[index].from, now)
            let boundary = endIndex + 1 < segments.count ? segments[endIndex + 1].from : horizon
            let until = min(boundary, start.addingTimeInterval(maxDuration))
            if until > now {
                steps.append(ScheduleLiveStep(face: face, start: start > now ? start : nil, until: until))
            }
            index = endIndex + 1
        }
        return steps
    }

    static func makeFace(_ segment: WidgetUpNextSegment) -> ScheduleLiveFace? {
        guard segment.state == .item, let primary = segment.primary else { return nil }
        let end = primary.endText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let time: String
        if primary.ongoing, let end, !end.isEmpty {
            time = "至 \(end)"
        } else {
            time = primary.timeText
        }
        return ScheduleLiveFace(
            timeText: time,
            ongoing: primary.ongoing,
            tag: blank(primary.tag),
            title: primary.title,
            place: blank(primary.place),
            extraCount: max(0, primary.extraCount),
            secondaryText: segment.secondary?.text,
            secondaryExam: segment.secondary?.kind == .exam,
            countdownLabel: primary.countdown?.label.rawValue,
            countdownEnd: primary.countdown?.target,
            link: segment.cardLink,
            isPrivate: primary.private
        )
    }

    private static func blank(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@available(iOS 16.2, *)
struct ScheduleLiveAttributes: ActivityAttributes {
    typealias ContentState = ScheduleLiveFace
}
