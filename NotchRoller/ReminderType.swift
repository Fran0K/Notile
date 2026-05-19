//
//  ReminderType.swift
//  notchEye
//
//  Created by Frank Lin on 2026/5/9.
//

import Foundation

struct ReminderItem: Codable, Identifiable, Equatable {
    let id: String          // built-in: "eyeRest" etc, custom: UUID
    var emoji: String
    var title: String
    var message: String
    var intervalMinutes: Double
    var durationSeconds: Double
    var lottieName: String?   // Lottie JSON filename (without .json), nil = use emoji
    let isBuiltIn: Bool

    // MARK: - Lottie

    /// Resolved lottie name: UserDefaults override > struct default
    var resolvedLottieName: String? {
        let override = UserDefaults.standard.string(forKey: lottieKey)?
            .trimmingCharacters(in: .whitespaces)
        if let override, !override.isEmpty { return override }
        return lottieName
    }

    var hasMedia: Bool {
        guard let name = resolvedLottieName else { return false }
        return resolveMediaPath(for: name) != nil
    }

    // MARK: - UserDefaults keys

    var enabledKey: String { "reminder_\(id)_enabled" }
    var intervalKey: String { "reminder_\(id)_interval" }
    var durationKey: String { "reminder_\(id)_duration" }
    var messageKey: String { "reminder_\(id)_message" }
    var lottieKey: String { "reminder_\(id)_lottie" }
    var emojiKey: String { id + "_emoji" }
    var titleKey: String { id + "_title" }

    // MARK: - Resolved values (UserDefaults override > struct default)

    var resolvedEmoji: String {
        UserDefaults.standard.string(forKey: emojiKey) ?? emoji
    }

    var resolvedTitle: String {
        UserDefaults.standard.string(forKey: titleKey) ?? title
    }

    var resolvedMessage: String {
        UserDefaults.standard.string(forKey: messageKey) ?? message
    }

    // MARK: - Built-in defaults

    static let builtIn: [ReminderItem] = [
        ReminderItem(
            id: "eyeRest", emoji: "", title: "眼睛休息",
            message: "望向窗外休息一下", intervalMinutes: 45,
            durationSeconds: 20, lottieName: "eye_blink", isBuiltIn: true
        ),
        ReminderItem(
            id: "drinkWater", emoji: "", title: "喝水",
            message: "该喝水了", intervalMinutes: 30,
            durationSeconds: 15, lottieName: "drink_water", isBuiltIn: true
        ),
        ReminderItem(
            id: "walkAround", emoji: "", title: "往外走走",
            message: "站起来活动一下", intervalMinutes: 60,
            durationSeconds: 20, lottieName: "walk_around", isBuiltIn: true
        ),
    ]
}

// MARK: - ReminderStore

@Observable
@MainActor
final class ReminderStore {

    var items: [ReminderItem] = []

    func item(withId id: String) -> ReminderItem? {
        items.first { $0.id == id }
    }

    private let storageKey = "reminders"

    init() {
        load()
    }

    // MARK: - CRUD

    func add(_ item: ReminderItem) {
        items.append(item)
        save()
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.map { items[$0].id }
        for i in offsets {
            items.remove(at: i)
        }
        save()
        for id in ids {
            NotificationCenter.default.post(name: .notchRollerItemDeleted, object: nil, userInfo: ["itemId": id])
        }
    }

    func delete(_ item: ReminderItem) {
        items.removeAll { $0.id == item.id }
        save()
        NotificationCenter.default.post(name: .notchRollerItemDeleted, object: nil, userInfo: ["itemId": item.id])
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ReminderItem].self, from: data) {
            items = decoded
        } else {
            // First launch: initialize with built-in
            items = ReminderItem.builtIn
            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Create a new custom reminder with unique ID
    static func makeCustom(emoji: String, title: String, message: String,
                           intervalMinutes: Double = 45, durationSeconds: Double = 20,
                           lottieName: String? = nil) -> ReminderItem {
        ReminderItem(
            id: UUID().uuidString,
            emoji: emoji,
            title: title,
            message: message,
            intervalMinutes: intervalMinutes,
            durationSeconds: durationSeconds,
            lottieName: lottieName,
            isBuiltIn: false
        )
    }
}
