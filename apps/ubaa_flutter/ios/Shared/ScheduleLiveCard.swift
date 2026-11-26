import ActivityKit
import Foundation

/// 通知中心实时活动要显示的一张「接下来」卡片。
/// 时刻写成两位小时。未上课只给出本节开始；上课后同时给出本节结束和本堂结束。
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
    /// 还没进入这一节时的上课时刻。已经在上课则为空。
    var classClock: String?
    var classStart: Date?
    /// 当前或下一节的下课时刻。没有节次表时与这堂下课相同。
    var sectionClock: String?
    var sectionEnd: Date?
    /// 这一堂课的结束时刻，可能跨两节或更多节。
    var periodClock: String?
    var periodEnd: Date?
    var link: String?
    var isPrivate: Bool

    /// 课表面貌。单节切换不放进这里，避免把整段学时拆成多张桌面卡。
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

enum ScheduleLiveClock {
    /// `9:35`、`明天 8:00`、`8:00–9:35` 里的时刻都补成两位小时。
    static func pad(_ text: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: #"(?<![0-9])([0-9]{1,2}):([0-9]{2})(?![0-9])"#)
        else { return text }
        let range = NSRange(text.startIndex..., in: text)
        var result = text
        for match in expression.matches(in: text, range: range).reversed() {
            guard let hourRange = Range(match.range(at: 1), in: result),
                  let minuteRange = Range(match.range(at: 2), in: result),
                  let hour = Int(result[hourRange])
            else { continue }
            let minute = result[minuteRange]
            let replacement = String(format: "%02d:%02d", hour, Int(minute) ?? 0)
            if let whole = Range(match.range, in: result) {
                result.replaceSubrange(whole, with: replacement)
            }
        }
        return result
    }

    /// 不足 60 分钟用「分秒」，满 60 分钟起用「时分」，秒不再显示。
    static func format(remaining seconds: Int) -> String {
        let seconds = max(0, seconds)
        if seconds >= 3_600 {
            return String(format: "%02d时%02d分", seconds / 3_600, (seconds % 3_600) / 60)
        }
        return String(format: "%02d分%02d秒", seconds / 60, seconds % 60)
    }

    static func remaining(until end: Date, now: Date) -> String {
        format(remaining: Int(end.timeIntervalSince(now).rounded(.down)))
    }

    static func clock(from date: Date) -> String {
        let parts = LocalDate.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
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
            guard let opened = makeFace(segments[index], at: segments[index].from, snapshot: snapshot) else {
                if !hasCurrent, steps.isEmpty { skippedLeading = true }
                index += 1
                continue
            }
            var endIndex = index
            while endIndex + 1 < segments.count,
                  let next = makeFace(segments[endIndex + 1], at: segments[endIndex + 1].from, snapshot: snapshot),
                  next.desktopKey == opened.desktopKey {
                endIndex += 1
            }
            let promote = steps.isEmpty && !hasCurrent && !skippedLeading
            let start = promote ? now : max(segments[index].from, now)
            let boundary = endIndex + 1 < segments.count ? segments[endIndex + 1].from : horizon
            let limit = min(boundary, start.addingTimeInterval(maxDuration))
            let ends = sectionBoundaries(segments[index], snapshot: snapshot)
            var cursor = start
            while steps.count < maxSteps, cursor < limit {
                guard let face = makeFace(segments[index], at: cursor, snapshot: snapshot) else { break }
                let nextSection = ends.first { $0 > cursor && $0 < limit }
                let until = nextSection ?? limit
                guard until > now else { cursor = until; continue }
                steps.append(ScheduleLiveStep(
                    face: face, start: cursor > now ? cursor : nil, until: until))
                guard nextSection != nil else { break }
                cursor = until
            }
            index = endIndex + 1
        }
        return steps
    }

    static func makeFace(
        _ segment: WidgetUpNextSegment, at now: Date, snapshot: WidgetSnapshot?
    ) -> ScheduleLiveFace? {
        guard segment.state == .item, let primary = segment.primary else { return nil }
        let end = primary.endText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let periodClock = end.map { ScheduleLiveClock.pad($0) }
        let slots = sectionSlots(primary, snapshot: snapshot)
        let sectionEnd = slots.map(\.end).first { $0 > now }
        let classStart = slots.first { $0.end > now }.flatMap { $0.start > now ? $0.start : nil }
            ?? primary.startAt.flatMap { $0 > now ? $0 : nil }
        let time: String
        if primary.ongoing, let periodClock, !periodClock.isEmpty {
            time = "至 \(periodClock)"
        } else {
            time = ScheduleLiveClock.pad(primary.timeText)
        }
        return ScheduleLiveFace(
            timeText: time,
            ongoing: primary.ongoing,
            tag: blank(primary.tag),
            title: primary.title,
            place: blank(primary.place),
            extraCount: max(0, primary.extraCount),
            secondaryText: segment.secondary.map { ScheduleLiveClock.pad($0.text) },
            secondaryExam: segment.secondary?.kind == .exam,
            countdownLabel: primary.countdown?.label.rawValue,
            countdownEnd: primary.countdown?.target,
            classClock: classStart.map(ScheduleLiveClock.clock(from:)),
            classStart: classStart,
            sectionClock: sectionEnd.map(ScheduleLiveClock.clock(from:)) ?? periodClock,
            sectionEnd: sectionEnd ?? primary.endAt,
            periodClock: periodClock,
            periodEnd: primary.endAt,
            link: segment.cardLink,
            isPrivate: primary.private
        )
    }

    /// 上课和每节下课的时刻。活动在这些点换内容。
    private static func sectionBoundaries(_ segment: WidgetUpNextSegment, snapshot: WidgetSnapshot?) -> [Date] {
        guard let primary = segment.primary else { return [] }
        return sectionSlots(primary, snapshot: snapshot).flatMap { [$0.start, $0.end] }
    }

    private struct SectionSlot {
        var start: Date
        var end: Date
    }

    /// 这一堂课里每一节的起止。对不上节次表时不另造。
    private static func sectionSlots(
        _ primary: WidgetUpNextSegment.Primary, snapshot: WidgetSnapshot?
    ) -> [SectionSlot] {
        guard let startAt = primary.startAt, let endAt = primary.endAt, let snapshot else { return [] }
        let begin = minutes(on: startAt)
        let finish = minutes(on: endAt)
        let day = LocalDate.today(now: startAt)
        for semester in snapshot.semesters {
            for week in semester.weeks where week.startDate <= day && day <= week.endDate {
                for course in week.arrangedList where course.courseName == primary.title
                    && course.dayOfWeek == Optional(day.isoWeekday)
                    && minutes(course.beginTime) == Optional(begin)
                    && minutes(course.endTime) == Optional(finish) {
                    guard let first = course.beginSection, let last = course.endSection, first <= last else {
                        return []
                    }
                    let dayStart = LocalDate.calendar.startOfDay(for: startAt)
                    return week.times
                        .filter { (first...last).contains($0.section) }
                        .compactMap { slot -> (Int, Int)? in
                            guard let start = minutes(slot.start), let end = minutes(slot.end), start < end
                            else { return nil }
                            return (start, end)
                        }
                        .sorted { $0.0 < $1.0 }
                        .compactMap { start, end in
                            guard let startDate = LocalDate.calendar.date(byAdding: .minute, value: start, to: dayStart),
                                  let endDate = LocalDate.calendar.date(byAdding: .minute, value: end, to: dayStart)
                            else { return nil }
                            return SectionSlot(start: startDate, end: endDate)
                        }
                }
            }
        }
        return []
    }

    private static func minutes(_ value: String?) -> Int? {
        guard let value else { return nil }
        guard let colon = value.lastIndex(of: ":") else { return nil }
        let hourText = value[..<colon].filter(\.isNumber)
        let minuteText = value[value.index(after: colon)...].prefix(2)
        guard hourText.count <= 2, minuteText.count == 2,
              let hour = Int(hourText), let minute = Int(minuteText),
              (0..<24).contains(hour), (0..<60).contains(minute)
        else { return nil }
        return hour * 60 + minute
    }

    private static func minutes(on date: Date) -> Int {
        let parts = LocalDate.calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
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
