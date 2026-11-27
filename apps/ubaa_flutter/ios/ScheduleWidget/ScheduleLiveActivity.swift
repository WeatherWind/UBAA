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
        VStack(alignment: .leading, spacing: prominent ? 14 : 8) {
            HStack(spacing: 8) {
                Text([face.dateText, face.tag].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                status(face.ongoing ? "进行中" : "接下来", palette: palette)
            }
            Spacer(minLength: 0)
            course(palette)
            Spacer(minLength: 0)
            if let footer = footerText {
                Text(footer)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(face.secondaryExam ? palette.accent : palette.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private func status(_ text: String, palette: SchedulePalette) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(face.ongoing ? palette.onAccent : palette.accent)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(face.ongoing ? palette.accent : palette.accent.opacity(0.14)))
    }

    private func course(_ palette: SchedulePalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(face.title)
                .font(.system(size: prominent ? 24 : 20, weight: .semibold))
                .foregroundStyle(palette.ink)
                .lineLimit(prominent ? 2 : 1)
                .minimumScaleFactor(0.8)
                .privacySensitive(face.isPrivate)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(face.scheduleText ?? face.timeText)
                    .font(.system(size: prominent ? 17 : 15, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
                if let countdown {
                    RemainingText(prefix: countdown.prefix, end: countdown.end,
                                  color: palette.secondary, size: 11)
                }
            }
            HStack(spacing: 8) {
                if let place = face.place, !place.isEmpty {
                    Text(place)
                        .font(.system(size: prominent ? 16 : 14, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if let teacher = face.teacher, !teacher.isEmpty {
                    Text(teacher)
                        .font(.system(size: prominent ? 16 : 14))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: prominent ? 320 : 300, alignment: .leading)
        .padding(.leading, 10)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(palette.accent)
                .frame(width: 4)
        }
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
            Text(end > context.date
                 ? "\(prefix) \(ScheduleLiveClock.remaining(until: end, now: context.date))"
                 : "\(prefix) 00分00秒")
                .font(.system(size: size, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .layoutPriority(1)
        }
    }
}
