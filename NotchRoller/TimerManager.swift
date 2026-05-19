//
//  TimerManager.swift
//  notchEye
//
//  Created by Frank Lin on 2026/5/6.
//

import Foundation
import Combine

extension Notification.Name {
    static let notchRollerTriggerNow = Notification.Name("notchRollerTriggerNow")
    static let notchRollerItemDeleted = Notification.Name("notchRollerItemDeleted")
    static let notchRollerDidExpand = Notification.Name("notchRollerDidExpand")
    static let notchRollerDidCollapse = Notification.Name("notchRollerDidCollapse")
}

@Observable
@MainActor
final class TimerManager {

    var isExpanded = false
    var activeItemId: String?   // which ReminderItem is currently showing

    let store = ReminderStore()

    private var timers: [String: Timer] = [:]
    private var collapseTimer: Timer?
    private var settingsCancellable: AnyCancellable?
    private var triggerCancellable: AnyCancellable?

    // MARK: - Settings for an item

    func isEnabled(_ item: ReminderItem) -> Bool {
        UserDefaults.standard.object(forKey: item.enabledKey) as? Bool ?? true
    }

    func interval(for item: ReminderItem) -> TimeInterval {
        let val = UserDefaults.standard.double(forKey: item.intervalKey)
        return (val > 0 ? val : item.intervalMinutes) * 60
    }

    func duration(for item: ReminderItem) -> TimeInterval {
        let val = UserDefaults.standard.double(forKey: item.durationKey)
        return val > 0 ? val : item.durationSeconds
    }

    func message(for item: ReminderItem) -> String {
        UserDefaults.standard.string(forKey: item.messageKey) ?? item.message
    }

    func activeItem() -> ReminderItem? {
        guard let id = activeItemId else { return nil }
        return store.item(withId: id)
    }

    // MARK: - Lifecycle

    func start() {
        observeSettings()
        observeTriggerNow()
        observeItemDeleted()
        scheduleAllEnabled()
    }

    func stop() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        collapseTimer?.invalidate()
    }

    /// Cancel timer for a deleted item
    func removeTimer(for itemId: String) {
        timers[itemId]?.invalidate()
        timers.removeValue(forKey: itemId)
    }

    func triggerNow(_ item: ReminderItem) {
        expand(item: item)
    }

    /// Test a specific item from Settings — handles collapse-if-expanded logic.
    func testItem(_ item: ReminderItem) {
        guard isEnabled(item) else { return }
        if isExpanded {
            isExpanded = false
            activeItemId = nil
            NotificationCenter.default.post(name: .notchRollerDidCollapse, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.expand(item: item)
            }
        } else {
            expand(item: item)
        }
    }

    // MARK: - Scheduling

    private func scheduleAllEnabled() {
        for item in store.items {
            if isEnabled(item) {
                scheduleReminder(item: item)
            }
        }
    }

    private func scheduleReminder(item: ReminderItem) {
        timers[item.id]?.invalidate()
        let interval = interval(for: item)
        timers[item.id] = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.expand(item: item)
            }
        }
    }

    // MARK: - Expand / Collapse

    private var isOutsideActiveHours: Bool {
        let ud = UserDefaults.standard

        guard ud.bool(forKey: "activeHoursEnabled") else { return false }

        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let currentMinutes = Double(now.hour ?? 0) * 60 + Double(now.minute ?? 0)
        let startMinutes = ud.double(forKey: "activeStartHour") * 60
        let endMinutes = ud.double(forKey: "activeEndHour") * 60

        if startMinutes <= endMinutes {
            // e.g. 08:00 - 22:00
            return !(currentMinutes >= startMinutes && currentMinutes < endMinutes)
        } else {
            // e.g. 22:00 - 08:00 (active overnight)
            return !(currentMinutes >= startMinutes || currentMinutes < endMinutes)
        }
    }


    private func expand(item: ReminderItem) {
        guard !isExpanded else {
            scheduleReminder(item: item)
            return
        }
        guard let stored = store.items.first(where: { $0.id == item.id }),
              isEnabled(stored) else { return }
        if isOutsideActiveHours {
            scheduleReminder(item: item)
            return
        }
        activeItemId = item.id
        isExpanded = true
        NotificationCenter.default.post(name: .notchRollerDidExpand, object: nil)
        collapseTimer?.invalidate()
        collapseTimer = Timer.scheduledTimer(
            withTimeInterval: duration(for: item),
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.collapse()
            }
        }
    }

    private func collapse() {
        let itemId = activeItemId
        isExpanded = false
        activeItemId = nil
        NotificationCenter.default.post(name: .notchRollerDidCollapse, object: nil)
        rescheduleItem(withId: itemId)
    }

    /// Cancel auto-collapse timer (called when user starts dragging).
    func cancelCollapseTimer() {
        collapseTimer?.invalidate()
        collapseTimer = nil
    }

    /// Called by NotchView after drag-initiated collapse animation completes.
    /// Does NOT trigger animation — NotchView handles that.
    func collapseFromDrag() {
        let itemId = activeItemId
        activeItemId = nil
        isExpanded = false
        NotificationCenter.default.post(name: .notchRollerDidCollapse, object: nil)
        rescheduleItem(withId: itemId)
    }

    func rescheduleItem(withId itemId: String?) {
        guard let itemId,
              let item = store.items.first(where: { $0.id == itemId }),
              isEnabled(item) else { return }
        scheduleReminder(item: item)
    }

    // MARK: - Observers

    private func observeSettings() {
        settingsCancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if !self.isExpanded {
                    self.stop()
                    self.scheduleAllEnabled()
                }
            }
    }

    private func observeTriggerNow() {
        triggerCancellable = NotificationCenter.default
            .publisher(for: .notchRollerTriggerNow)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let item = self.store.items.first { self.isEnabled($0) }
                    ?? self.store.items.first
                    ?? ReminderItem.builtIn[0]
                if self.isExpanded {
                    self.isExpanded = false
                    self.activeItemId = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.expand(item: item)
                    }
                } else {
                    self.expand(item: item)
                }
            }
    }

    private func observeItemDeleted() {
        NotificationCenter.default.addObserver(
            forName: .notchRollerItemDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let itemId = notification.userInfo?["itemId"] as? String else { return }
            self.removeTimer(for: itemId)
            // If currently showing this item, collapse immediately
            if self.activeItemId == itemId {
                self.isExpanded = false
                self.activeItemId = nil
            }
        }
    }
}
