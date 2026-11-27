import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct ScheduleLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScheduleLiveAttributes.self) { context in
            ScheduleLiveChrome {
                ScheduleLiveFaceView(face: context.state)
            }
            .widgetURL(ScheduleLiveLink.url(context.state.link))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ScheduleLiveFaceView(face: context.state, prominent: false)
                }
            } compactLeading: {
                Text(context.state.classClock ?? context.state.sectionClock ?? context.state.timeText)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } compactTrailing: {
                Text(context.state.ongoing
                     ? (context.state.periodClock ?? context.state.place ?? context.state.title)
                     : (context.state.place ?? context.state.title))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .privacySensitive(context.state.periodClock == nil && context.state.place == nil && context.state.isPrivate)
            } minimal: {
                Text(context.state.classClock ?? context.state.sectionClock ?? (context.state.ongoing ? "进行中" : context.state.timeText))
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .widgetURL(ScheduleLiveLink.url(context.state.link))
        }
    }
}

@available(iOS 16.2, *)
private enum ScheduleLiveLink {
    static func url(_ raw: String?) -> URL? {
        guard let raw, raw.hasPrefix("ubaa://widget/open?") else { return nil }
        return URL(string: raw)
    }
}

@available(iOS 16.2, *)
private struct ScheduleLiveChrome<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        let palette = SchedulePalette.resolve(theme: .ocean, scheme: scheme, accented: false)
        content()
            .activityBackgroundTint(palette.canvas)
            .activitySystemActionForegroundColor(palette.accent)
    }
}

@available(iOS 16.2, *)
private struct ScheduleLiveFaceView: View {
    var face: ScheduleLiveFace
    var prominent = true
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = SchedulePalette.resolve(theme: .ocean, scheme: scheme, accented: false)
        VStack(alignment: .leading, spacing: prominent ? 8 : 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(clockHero)
                            .font(.system(size: prominent ? 24 : 20, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 0)
                        if let tag = face.tag, !tag.isEmpty {
                            Text(tag)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(palette.accent)
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(palette.accent.opacity(0.14)))
                        }
                        if face.extraCount > 0 {
                            Text("+\(face.extraCount)")
                                .font(.system(size: 11))
                                .foregroundStyle(palette.tertiary)
                                .fixedSize()
                        }
                    }
                    if !clockSub.isEmpty {
                        Text(clockSub)
                            .font(.system(size: prominent ? 12 : 11, weight: .medium))
                            .foregroundStyle(palette.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(face.title)
                            .font(.system(size: prominent ? 15 : 13, weight: .semibold))
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .privacySensitive(face.isPrivate)
                        if let place = face.place, !place.isEmpty {
                            Text(place)
                                .font(.system(size: prominent ? 13 : 12, weight: .medium))
                                .foregroundStyle(palette.secondary)
                                .lineLimit(clockSub.isEmpty ? 2 : 1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .padding(.leading, prominent ? 9 : 8)
                    .overlay(alignment: .leading) {
                        Capsule().fill(palette.accent).frame(width: 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(face.ongoing ? "进行中" : "接下来")
                        .font(.system(size: prominent ? 13 : 12, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                    if let countdown {
                        Text(countdown.prefix)
                            .font(.system(size: prominent ? 13 : 12, weight: .medium))
                            .foregroundStyle(palette.secondary)
                            .padding(.top, prominent ? 2 : 1)
                        RemainingText(
                            prefix: "",
                            end: countdown.end,
                            color: palette.accent,
                            size: prominent ? 26 : 20
                        )
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            if let footer = footerText {
                Text(footer)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(face.secondaryExam ? palette.accent : palette.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 小尺寸「接下来」的第一行是时刻，不是课名。
    private var clockHero: String {
        face.scheduleText ?? face.timeText
    }

    /// 上课中补本节下课，对应小卡片时刻下面的那一行。
    private var clockSub: String {
        guard face.ongoing, let section = face.sectionClock, !section.isEmpty else { return "" }
        return "本节至 \(section)"
    }

    private var countdown: (prefix: String, end: Date)? {
        if let classStart = face.classStart {
            return ("还有", classStart)
        }
        if face.ongoing, let sectionEnd = face.sectionEnd {
            return ("还剩", sectionEnd)
        }
        if let countdownEnd = face.countdownEnd {
            return (face.countdownLabel ?? (face.ongoing ? "还剩" : "还有"), countdownEnd)
        }
        return nil
    }

    private var footerText: String? {
        if let secondary = face.secondaryText, !secondary.isEmpty {
            return secondary
        }
        return face.extraCount > 0 ? "还有 \(face.extraCount) 项" : nil
    }
}

@available(iOS 16.2, *)
private struct RemainingText: View {
    var prefix: String
    var end: Date
    var color: Color
    var size: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = end > context.date
                ? ScheduleLiveClock.remaining(until: end, now: context.date)
                : "00分00秒"
            Text(prefix.isEmpty ? remaining : "\(prefix) \(remaining)")
                .font(.system(size: size, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .layoutPriority(1)
        }
    }
}

#if DEBUG
@available(iOS 16.2, *)
private enum ScheduleLivePreviewData {
    static var ongoing: ScheduleLiveFace {
        sample(
            ongoing: true,
            timeText: "至 09:35",
            classStart: nil,
            countdownEnd: .now.addingTimeInterval(12 * 60 + 8),
            sectionEnd: .now.addingTimeInterval(12 * 60 + 8)
        )
    }

    static var upcoming: ScheduleLiveFace {
        sample(
            ongoing: false,
            timeText: "08:00–09:35",
            classStart: .now.addingTimeInterval(18 * 60 + 20),
            countdownEnd: .now.addingTimeInterval(18 * 60 + 20),
            sectionEnd: .now.addingTimeInterval(63 * 60)
        )
    }

    private static func sample(
        ongoing: Bool,
        timeText: String,
        classStart: Date?,
        countdownEnd: Date,
        sectionEnd: Date
    ) -> ScheduleLiveFace {
        ScheduleLiveFace(
            timeText: timeText,
            scheduleText: "08:00–09:35",
            dateText: "周一 11-16",
            ongoing: ongoing,
            tag: nil,
            title: "高等数学",
            place: "主楼 A201",
            teacher: "合成教师",
            extraCount: 0,
            secondaryText: "下一节 10:10 大学英语 教一 B305",
            secondaryExam: false,
            countdownLabel: ongoing ? "还剩" : "还有",
            countdownEnd: countdownEnd,
            classClock: classStart == nil ? nil : "08:00",
            classStart: classStart,
            sectionClock: ongoing ? "08:45" : "09:35",
            sectionEnd: sectionEnd,
            periodClock: "09:35",
            periodEnd: sectionEnd.addingTimeInterval(50 * 60),
            link: nil,
            isPrivate: false
        )
    }
}

@available(iOS 17.0, *)
#Preview("现在 · 上课中", as: .content, using: ScheduleLiveAttributes()) {
    ScheduleLiveActivityWidget()
} contentStates: {
    ScheduleLivePreviewData.ongoing
}

@available(iOS 17.0, *)
#Preview("现在 · 还没上课", as: .content, using: ScheduleLiveAttributes()) {
    ScheduleLiveActivityWidget()
} contentStates: {
    ScheduleLivePreviewData.upcoming
}

@available(iOS 17.0, *)
#Preview("现在 · 灵动岛", as: .dynamicIsland(.expanded), using: ScheduleLiveAttributes()) {
    ScheduleLiveActivityWidget()
} contentStates: {
    ScheduleLivePreviewData.ongoing
}

#endif
