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
                Text(context.state.timeText)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } compactTrailing: {
                Text(context.state.place ?? context.state.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .privacySensitive(context.state.place == nil && context.state.isPrivate)
            } minimal: {
                Text(context.state.ongoing ? "进行中" : context.state.timeText)
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
        VStack(alignment: .leading, spacing: 4) {
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
                Spacer(minLength: 0)
                if face.extraCount > 0 {
                    Text("+\(face.extraCount)")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.tertiary)
                }
            }
            Text(face.timeText)
                .font(.system(size: prominent ? 22 : 18, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(face.ongoing ? palette.accent : palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let timer = countdown {
                timer
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            HStack(alignment: .top, spacing: 6) {
                Capsule().fill(palette.accent).frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    if let place = face.place {
                        Text(place)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                    }
                    Text(face.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(prominent ? 2 : 1)
                        .privacySensitive(face.isPrivate)
                }
            }
            if let secondary = face.secondaryText, !secondary.isEmpty {
                Text(secondary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(face.secondaryExam ? palette.accent : palette.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var countdown: Text? {
        guard let label = face.countdownLabel, let end = face.countdownEnd, end > Date() else { return nil }
        return Text("\(label) \(Text(timerInterval: Date()...end, countsDown: true))")
    }
}
