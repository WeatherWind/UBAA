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
        VStack(spacing: 8) {
            header(palette)
            Text(face.title)
                .font(.system(size: prominent ? 22 : 18, weight: .semibold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(prominent ? 2 : 1)
                .privacySensitive(face.isPrivate)
                .frame(maxWidth: .infinity)
            if let place = face.place {
                Text(place)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            if face.ongoing {
                HStack(alignment: .top, spacing: 0) {
                    if face.classStart != nil {
                        mark("本节课开始于", clock: face.classClock, end: face.classStart, prefix: "还有", palette: palette)
                        Rectangle().fill(palette.hairline).frame(width: 1).padding(.vertical, 2)
                    }
                    mark("本节课结束于", clock: face.sectionClock, end: face.sectionEnd, prefix: "还剩", palette: palette)
                    Rectangle().fill(palette.hairline).frame(width: 1).padding(.vertical, 2)
                    mark("本堂课结束于", clock: face.periodClock, end: face.periodEnd, prefix: "还剩", palette: palette)
                }
            } else {
                mark(
                    "本节课开始于",
                    clock: face.classClock ?? face.timeText,
                    end: face.classStart ?? face.countdownEnd,
                    prefix: "还有",
                    palette: palette
                )
            }
            if let secondary = face.secondaryText, !secondary.isEmpty {
                Text(secondary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(face.secondaryExam ? palette.accent : palette.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func header(_ palette: SchedulePalette) -> some View {
        if face.ongoing || face.tag != nil || face.extraCount > 0 {
        ZStack {
            HStack(spacing: 4) {
                if face.ongoing {
                    Text("进行中")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.onAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(palette.accent))
                }
                if let tag = face.tag {
                    Text(tag)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(palette.accent.opacity(0.14)))
                }
            }
            .frame(maxWidth: .infinity)
            if face.extraCount > 0 {
                Text("+\(face.extraCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        }
    }

    private func mark(
        _ name: String, clock: String?, end: Date?, prefix: String, palette: SchedulePalette
    ) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(clock ?? "—")
                .font(.system(size: prominent ? 22 : 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let end {
                RemainingText(prefix: prefix, end: end, color: palette.accent, size: 11)
            }
        }
        .frame(maxWidth: .infinity)
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
                .minimumScaleFactor(0.7)
        }
    }
}
