import XCTest

final class ScheduleLiveCardTests: XCTestCase {
    func testOngoingFaceUsesDesktopUntilAndHandsOffAtNextClass() throws {
        let snapshot = try ScheduleWidgetParser.parseSnapshot(WidgetV2Tests.fixture())
        let now = Date(timeIntervalSince1970: 1_794_787_200)
        let steps = ScheduleLivePlan.steps(now: now, snapshot: snapshot)
        let current = try XCTUnwrap(steps.first)
        XCTAssertNil(current.start)
        XCTAssertEqual(current.face.timeText, "至 9:35")
        XCTAssertTrue(current.face.ongoing)
        XCTAssertEqual(current.face.alertTitle, "进行中")
        XCTAssertEqual(current.face.title, "高等数学")
        XCTAssertEqual(current.face.place, "主楼 A201")
        XCTAssertEqual(current.face.secondaryText, "下一节 10:10 教一 B305")
        XCTAssertFalse(current.face.secondaryExam)
        XCTAssertEqual(current.face.countdownLabel, "还剩")
        XCTAssertEqual(current.until, Date(timeIntervalSince1970: 1_794_792_900))

        let next = try XCTUnwrap(steps.dropFirst().first)
        XCTAssertEqual(next.start, Date(timeIntervalSince1970: 1_794_792_900))
        XCTAssertEqual(next.face.title, "大学英语")
        XCTAssertEqual(next.face.timeText, "10:10")
        XCTAssertFalse(next.face.ongoing)
        XCTAssertEqual(next.face.alertTitle, "接下来")
        XCTAssertEqual(next.face.alertBody, "10:10 教一 B305 大学英语")
        XCTAssertEqual(next.until, Date(timeIntervalSince1970: 1_794_795_000))
    }

    func testCountdownAppearanceDoesNotSplitTheDesktopFace() throws {
        let start = 1_700_000_000
        let snapshot = try liveSnapshot(horizon: start + 20_000, rows: [
            item(from: start, title: "高等数学", time: "8:00", end: "9:35", place: "主楼 A201"),
            item(from: start + 100, title: "高等数学", time: "8:00", end: "9:35", place: "主楼 A201",
                 countdown: ["label": "还有", "target": start + 200]),
            item(from: start + 200, title: "高等数学", time: "8:00–9:35", end: "9:35", place: "主楼 A201",
                 ongoing: true, countdown: ["label": "还剩", "target": start + 800]),
        ])
        let steps = ScheduleLivePlan.steps(now: Date(timeIntervalSince1970: TimeInterval(start)), snapshot: snapshot)
        XCTAssertEqual(steps.count, 2)
        XCTAssertNil(steps[0].start)
        XCTAssertNil(steps[0].face.countdownLabel)
        XCTAssertEqual(steps[0].face.timeText, "8:00")
        XCTAssertEqual(steps[0].until, Date(timeIntervalSince1970: TimeInterval(start + 200)))
        XCTAssertEqual(steps[1].face.timeText, "至 9:35")
        XCTAssertEqual(steps[1].face.countdownLabel, "还剩")
        XCTAssertEqual(steps[1].start, Date(timeIntervalSince1970: TimeInterval(start + 200)))
    }

    func testOpeningDuringCountdownKeepsTheHourLabel() throws {
        let start = 1_700_000_000
        let snapshot = try liveSnapshot(horizon: start + 20_000, rows: [
            item(from: start, title: "高等数学", time: "8:00", end: "9:35", place: "主楼 A201"),
            item(from: start + 100, title: "高等数学", time: "8:00", end: "9:35", place: "主楼 A201",
                 countdown: ["label": "还有", "target": start + 200]),
        ])
        let steps = ScheduleLivePlan.steps(
            now: Date(timeIntervalSince1970: TimeInterval(start + 100)), snapshot: snapshot)
        XCTAssertEqual(steps.count, 1)
        XCTAssertNil(steps[0].start)
        XCTAssertEqual(steps[0].face.countdownLabel, "还有")
        XCTAssertEqual(steps[0].face.timeText, "8:00")
    }

    func testQuietGapSchedulesTheNextItemInsteadOfShowingItNow() throws {
        let start = 1_700_000_000
        let snapshot = try liveSnapshot(horizon: start + 10_000, rows: [
            quiet(from: start, state: "none", message: "近期没有安排"),
            item(from: start + 3_600, title: "大学英语", time: "10:10", end: "11:45", place: "教一 B305"),
        ])
        let steps = ScheduleLivePlan.steps(
            now: Date(timeIntervalSince1970: TimeInterval(start + 10)), snapshot: snapshot)
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].start, Date(timeIntervalSince1970: TimeInterval(start + 3_600)))
        XCTAssertEqual(steps[0].face.title, "大学英语")
        XCTAssertEqual(steps[0].face.alertTitle, "接下来")
    }

    func testBeforeTheFirstSegmentShowsThatClassImmediately() throws {
        let start = 1_700_000_000
        let snapshot = try liveSnapshot(horizon: start + 10_000, rows: [
            item(from: start + 600, title: "高等数学", time: "明天 8:00", end: "9:35", place: "主楼 A201"),
            item(from: start + 1_200, title: "大学英语", time: "明天 10:10", end: "11:45", place: "教一 B305"),
        ])
        let now = Date(timeIntervalSince1970: TimeInterval(start))
        let steps = ScheduleLivePlan.steps(now: now, snapshot: snapshot)
        XCTAssertNil(steps[0].start)
        XCTAssertEqual(steps[0].face.timeText, "明天 8:00")
        XCTAssertEqual(steps[0].until, Date(timeIntervalSince1970: TimeInterval(start + 1_200)))
        XCTAssertEqual(steps[1].start, Date(timeIntervalSince1970: TimeInterval(start + 1_200)))
    }

    func testOnlyTheNextHandoffIsScheduled() throws {
        let start = 1_700_000_000
        let rows = (0..<4).map { index in
            item(from: start + index * 100, title: "合成\(index)", time: "\(index):00", end: "\(index):45",
                 place: "教室 \(index)")
        }
        let snapshot = try liveSnapshot(horizon: start + 10_000, rows: rows)
        let steps = ScheduleLivePlan.steps(now: Date(timeIntervalSince1970: TimeInterval(start)), snapshot: snapshot)
        XCTAssertEqual(steps.map(\.face.title), ["合成0", "合成1"])
        XCTAssertEqual(steps.map(\.start), [nil, Date(timeIntervalSince1970: TimeInterval(start + 100))])
    }

    func testLongFaceEndsAtTheEightHourLimit() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = try liveSnapshot(horizon: 1_700_000_000 + 20 * 3_600, rows: [
            item(from: 1_700_000_000 - 60, title: "高等数学", time: "8:00", end: "9:35", place: "主楼 A201"),
        ])
        let steps = ScheduleLivePlan.steps(now: now, snapshot: snapshot)
        XCTAssertEqual(steps.count, 1)
        XCTAssertNil(steps[0].start)
        XCTAssertEqual(steps[0].until, now.addingTimeInterval(ScheduleLivePlan.maxDuration))
    }

    func testHorizonMissAndEmptySnapshotProduceNoCard() throws {
        let snapshot = try liveSnapshot(horizon: 1_800_000_000, rows: [
            item(from: 1_700_000_000, title: "高等数学", time: "8:00", end: "9:35", place: "主楼 A201"),
        ])
        XCTAssertTrue(ScheduleLivePlan.steps(
            now: Date(timeIntervalSince1970: 1_800_000_000), snapshot: snapshot).isEmpty)
        XCTAssertTrue(ScheduleLivePlan.steps(
            now: Date(timeIntervalSince1970: 1_700_000_000), snapshot: nil).isEmpty)
        let weekOnly = try ScheduleWidgetParser.parseSnapshot([
            "version": 1, "owner": "合成甲", "semesters": [],
        ])
        XCTAssertTrue(ScheduleLivePlan.steps(
            now: Date(timeIntervalSince1970: 1_700_000_000), snapshot: weekOnly).isEmpty)
    }

    func testPrivateClassOmitsTheTitleFromTheAlert() throws {
        var row = item(from: 1_700_000_000, title: "合成私事", time: "14:00", end: "15:00", place: "研讨室 305")
        var primary = try XCTUnwrap(row["primary"] as? [String: Any])
        primary["private"] = true
        primary["tag"] = "预约"
        primary["extraCount"] = 2
        row["primary"] = primary
        row["secondary"] = ["kind": "exam", "text": "14:00 考试 · 主 M101", "private": false, "link": NSNull()]
        let snapshot = try liveSnapshot(horizon: 1_700_010_000, rows: [row])
        let face = try XCTUnwrap(ScheduleLivePlan.steps(
            now: Date(timeIntervalSince1970: 1_700_000_000), snapshot: snapshot).first?.face)
        XCTAssertEqual(face.tag, "预约")
        XCTAssertEqual(face.extraCount, 2)
        XCTAssertTrue(face.secondaryExam)
        XCTAssertEqual(face.secondaryText, "14:00 考试 · 主 M101")
        XCTAssertTrue(face.isPrivate)
        XCTAssertEqual(face.alertBody, "14:00 研讨室 305")
    }

    private func liveSnapshot(horizon: Int, rows: [[String: Any]]) throws -> WidgetSnapshot {
        try ScheduleWidgetParser.parseSnapshot([
            "version": 2, "owner": "合成甲", "semesters": [],
            "horizonEnd": horizon, "upNext": rows,
        ])
    }

    private func item(
        from: Int, title: String, time: String, end: String, place: String,
        ongoing: Bool = false, countdown: [String: Any]? = nil
    ) -> [String: Any] {
        var primary: [String: Any] = [
            "kind": "course", "title": title, "place": place, "timeText": time,
            "dayText": "", "startText": time, "endText": end, "ongoing": ongoing,
            "extraCount": 0, "private": false,
        ]
        if let countdown { primary["countdown"] = countdown }
        return [
            "from": from, "state": "item", "primary": primary,
            "cardLink": "ubaa://widget/open?target=schedule",
        ]
    }

    private func quiet(from: Int, state: String, message: String) -> [String: Any] {
        ["from": from, "state": state, "message": message]
    }
}
