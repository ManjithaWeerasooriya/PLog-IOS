//
//  RestTimer.swift
//  PLog
//
//  The rest countdown between sets. One timer for the whole app, so it keeps running when
//  the user leaves the session screen, and counted against an end date rather than ticks, so
//  it's still right after the app has been in the background. It's started by hand: a set
//  has no "done" tick to start it from (see AGENT.md), and one tap after racking the bar is
//  the simpler contract anyway.
//

import Foundation
import UserNotifications

@MainActor
@Observable
final class RestTimer {
    static let shared = RestTimer()

    /// `UserDefaults` keys: the chosen rest length in seconds, and whether to post a
    /// notification when rest ends while the app is in the background.
    static let durationKey = "restTimerSeconds"
    static let alertsKey = "restTimerAlerts"

    /// Rest lengths on offer. Research finds a small benefit to resting more than a minute
    /// and little past ninety seconds for growth; heavy compounds want the longer ones.
    static let presets = [60, 90, 120, 180, 240, 300]
    static let defaultDuration = 120

    /// When the running countdown ends; `nil` while idle.
    private(set) var endDate: Date?
    /// The running countdown's full length, for the progress bar.
    private(set) var total: TimeInterval = 0
    /// Goes up by one each time a countdown runs out, for the "rest over" haptic.
    private(set) var finishedCount = 0

    /// The rest length a new countdown starts with.
    var duration: Int {
        didSet { defaults.set(duration, forKey: Self.durationKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var completion: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.integer(forKey: Self.durationKey)
        duration = saved > 0 ? saved : Self.defaultDuration
    }

    var isRunning: Bool { endDate != nil }

    /// Seconds left at `now`; 0 when idle or finished.
    func remaining(at now: Date = .now) -> TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(now))
    }

    /// 0 at the start of a countdown, 1 at the end.
    func progress(at now: Date = .now) -> Double {
        guard isRunning, total > 0 else { return 0 }
        return min(max(1 - remaining(at: now) / total, 0), 1)
    }

    func start(now: Date = .now) {
        total = TimeInterval(duration)
        endDate = now.addingTimeInterval(total)
        schedule()
    }

    /// Lengthens (or, with a negative value, shortens) the running countdown.
    func add(_ seconds: TimeInterval, now: Date = .now) {
        guard let endDate else { return }
        let newEnd = max(endDate.addingTimeInterval(seconds), now)
        total = max(total + seconds, 1)
        self.endDate = newEnd
        schedule()
    }

    func stop() {
        endDate = nil
        completion?.cancel()
        completion = nil
        cancelAlert()
    }

    /// Ends the countdown as finished. Called when it runs out.
    func finish() {
        guard isRunning else { return }
        endDate = nil
        completion = nil
        finishedCount += 1
    }

    private func schedule() {
        completion?.cancel()
        guard let endDate else { return }
        completion = Task { [weak self] in
            let wait = max(0, endDate.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
        scheduleAlert(for: endDate)
    }

    // MARK: - Background alert

    private static let alertID = "rest-timer"

    /// A notification for when rest ends with the app in the background — iOS doesn't show
    /// it while the app is in front, where the haptic does the job. Only when the user has
    /// switched alerts on in Settings (which is also where permission is asked for).
    private func scheduleAlert(for endDate: Date) {
        cancelAlert()
        guard defaults.bool(forKey: Self.alertsKey) else { return }
        let seconds = endDate.timeIntervalSinceNow
        guard seconds >= 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.alertID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelAlert() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.alertID])
    }

    /// Asks for permission to notify. Returns whether alerts can be shown.
    static func requestAlertPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    // MARK: - Formatting

    /// "2:00", "0:45".
    static func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.up))
        return "\(whole / 60):" + String(format: "%02d", whole % 60)
    }

    /// "2 min", "1 min 30 sec" — for the length menu and VoiceOver.
    static func spoken(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let rest = seconds % 60
        if minutes == 0 { return "\(rest) sec" }
        return rest == 0 ? "\(minutes) min" : "\(minutes) min \(rest) sec"
    }
}
