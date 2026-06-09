//
//  SettingsView.swift
//  notchEye
//
//  Created by Frank Lin on 2026/5/6.
//

import SwiftUI
import ServiceManagement
import Lottie
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("tab.general", systemImage: "gearshape.circle") }
            DisplayTab()
                .tabItem { Label("tab.items", systemImage: "list.bullet.circle") }
            AboutTab()
                .tabItem { Label("tab.about", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 550)
        .background(.thinMaterial)
        .environment(\.locale, appLanguage.locale)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @AppStorage("expandedWidth") private var expandedWidth: Double = 300
    @AppStorage("expandedHeight") private var expandedHeight: Double = 120
    @AppStorage("isPreviewing") private var isPreviewing: Bool = false
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    @AppStorage("activeHoursEnabled") private var activeHoursEnabled: Bool = false
    @AppStorage("activeStartHour") private var activeStartHour: Double = 8
    @AppStorage("activeEndHour") private var activeEndHour: Double = 22

    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system
    @AppStorage("selectedDisplayID") private var selectedDisplayID: Int = 0

    private var screenSize: CGSize {
        ScreenResolver.resolveTargetScreen()?.frame.size
            ?? NSScreen.screens.first?.frame.size
            ?? CGSize(width: 1920, height: 1080)
    }

    private struct ScreenEntry: Identifiable {
        let id: Int
        let label: String
    }

    private var availableScreens: [ScreenEntry] {
        NSScreen.screens.map { screen in
            ScreenEntry(id: ScreenResolver.screenID(screen), label: ScreenResolver.screenLabel(screen))
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
        Form {
            Section("settings.general.language") {
                Picker("settings.general.language", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }

//            Section("settings.general.monitor") {
//                Picker("settings.general.monitor", selection: $selectedDisplayID) {
//                    ForEach(availableScreens, id: \.id) { entry in
//                        Text(entry.label).tag(entry.id)
//                    }
//                }
//                .onChange(of: selectedDisplayID) { _, _ in
//                    if let appDelegate = AppDelegate.shared {
//                        if !appDelegate.timerManager.isExpanded {
//                            appDelegate.panelProxy.collapsePanel()
//                        }
//                    }
//                }
//            }
            
            Section("settings.general.monitor") {
                HStack(spacing: 16) {
                    ForEach(availableScreens, id: \.id) { entry in
                        let isSelected = selectedDisplayID == entry.id
                        
                        // 判断是否为内置视网膜显示器（支持包含 "Built-in" 或 "Retina" 等关键字的模糊匹配）
                        let isBuiltIn = entry.label.localizedCaseInsensitiveContains("Built-in")

                        Button {
                            selectedDisplayID = entry.id
                        } label: {
                            VStack(spacing: 12) {
                                // 1. 显示器 SVG 图片（在 Assets 中对应的名字，不带 .svg 后缀）
                                // 提示：如果想使用系统自带的免资源图标，可以用 SF Symbols:
                                // isBuiltIn ? "laptopcomputer" : "desktopcomputer"
                                let imageName = isBuiltIn ? "images/macbook" : "images/monitor"
                                Image(imageName)
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(isSelected ? Color.accentColor : Color(nsColor: .textColor))
//                                    .foregroundStyle(isSelected ? .primary : .secondary)

                                // 2. 显示器名称
                                Text(entry.label)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(height: 32) // 固定高度防止文字换行撑开卡片
                                
                                // 3. 圆形单选按钮
                                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            }
                            .padding(16)
                            .frame(width: 140, height: 150)
                            // 背景色适应深浅色模式
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                            // 选中状态加上蓝色边框高亮，未选中则是普通灰色边框
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain) // 去除 macOS 默认 Button 的高亮变灰效果
                    }
                }
                .padding(.vertical, 8)
                // 监听选择变化
                .onChange(of: selectedDisplayID) { _, _ in
                    if let appDelegate = AppDelegate.shared {
                        if !appDelegate.timerManager.isExpanded {
                            appDelegate.panelProxy.collapsePanel()
                        }
                    }
                }
            }

            Section("settings.general.launch") {
                Toggle("settings.general.startAtLogin", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = false
                        }
                    }
            }

            Section {
                Toggle("settings.general.enableActiveHours", isOn: $activeHoursEnabled)

                if activeHoursEnabled {
                    HStack {
                        VStack(alignment: .center, spacing: 4) {
                            Text("settings.general.start")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $activeStartHour) {
                                ForEach(Array(stride(from: 0, to: 24, by: 0.5)), id: \.self) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .labelsHidden()
                        }

                        Spacer()

                        VStack(alignment: .center, spacing: 4) {
                            Text("settings.general.end")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $activeEndHour) {
                                ForEach(Array(stride(from: 0, to: 24, by: 0.5)), id: \.self) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }
            } header: {
                Text("settings.general.activeHours")
            }


            Section("settings.general.size") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("settings.general.expandSize")
                            .fontWeight(.bold)
                        Text("settings.general.expandSizeDesc")
                            .font(.body)
                    }
                    Spacer()
                }.padding()

                HStack(alignment: .center) {
                    VStack(alignment: .center, spacing: 4) {
                        Text("settings.general.width")
                            .fontWeight(.bold)
                        Text("\(Int(expandedWidth)) \(String(localized: "settings.general.pt"))")
                        Slider(value: $expandedWidth, in: 160...screenSize.width * 0.8, step: 10) {
                        } onEditingChanged: { editing in
                            isPreviewing = editing
                        }
                        .labelsHidden()
                        .padding(.horizontal)
                    }

                    Text("×")
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .center, spacing: 4) {
                        Text("settings.general.height")
                            .fontWeight(.bold)
                        Text("\(Int(expandedHeight)) \(String(localized: "settings.general.pt"))")
                        Slider(value: $expandedHeight, in: 60...screenSize.height * 0.8, step: 10) {
                        } onEditingChanged: { editing in
                            isPreviewing = editing
                        }
                        .labelsHidden()
                        .padding(.horizontal)
                    }
                }
            }

        }
        .formStyle(.grouped)
        .padding()
        }
    }

    private func formatHour(_ value: Double) -> String {
        let hours = Int(value)
        let minutes = Int((value - Double(hours)) * 60)
        return String(format: "%02d:%02d", hours, minutes)
    }
}

// MARK: - Display Tab

struct DisplayTab: View {
    let store = AppDelegate.shared?.timerManager.store ?? ReminderStore()
    @State private var showingAddSheet = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                ForEach(store.items) { item in
                    ReminderConfigRow(item: item, store: store)
                }

                // Add button
                Button(action: { showingAddSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("display.addReminder")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddReminderSheet(store: store)
        }
    }
}

// MARK: - Reminder Config Row

enum RowState { case collapsed, expanded, editing }

struct ReminderConfigRow: View {
    let item: ReminderItem
    let store: ReminderStore

    @AppStorage private var enabled: Bool
    @AppStorage private var intervalMinutes: Double
    @AppStorage private var durationSeconds: Double
    @AppStorage private var customMessage: String
    @AppStorage private var customTitle: String
    @AppStorage private var customLottieName: String

    @State private var rowState: RowState = .collapsed
    @State private var showingDeleteConfirm = false

    // Scratch copies for edit → cancel
    @State private var draftTitle: String = ""
    @State private var draftMessage: String = ""
    @State private var draftInterval: Double = 0
    @State private var draftDuration: Double = 0
    @State private var draftLottieName: String = ""

    init(item: ReminderItem, store: ReminderStore) {
        self.item = item
        self.store = store
        self._enabled = AppStorage(wrappedValue: true, item.enabledKey)
        self._intervalMinutes = AppStorage(wrappedValue: item.intervalMinutes, item.intervalKey)
        self._durationSeconds = AppStorage(wrappedValue: item.durationSeconds, item.durationKey)
        self._customMessage = AppStorage(wrappedValue: item.message, item.messageKey)
        self._customTitle = AppStorage(wrappedValue: item.title, item.id + "_title")
        self._customLottieName = AppStorage(wrappedValue: item.lottieName ?? "", item.lottieKey)
    }

    private var resolvedLottieName: String? {
        let name = customLottieName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private var hasResolvedLottie: Bool {
        guard let name = resolvedLottieName else { return false }
        return resolveMediaPath(for: name) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // — Header (always visible, clickable to expand/collapse)
            headerRow
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        rowState = rowState == .collapsed ? .expanded : .collapsed
                    }
                }

            // — Expanded: read-only info + edit/delete buttons
            if rowState == .expanded {
                Divider()
                readOnlyInfo
                actionButtons
            }

            // — Editing: editable fields + save/cancel
            if rowState == .editing {
                Divider()
                editForm
                saveCancelButtons
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            iconView(size: 32)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading) {
                Text(customTitle)
                    .fontWeight(.bold)
                Text(customMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: rowState == .collapsed ? "chevron.down" : "chevron.up")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("", isOn: $enabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    // MARK: - Read-only info

    private var readOnlyInfo: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text("display.interval")
                    .fontWeight(.semibold)
                Text("\(Int(intervalMinutes)) \(String(localized: "display.minutes"))")
                    .fontWeight(.light)
                Spacer()
                Text("display.duration")
                    .fontWeight(.semibold)
                Text("\(Int(durationSeconds)) \(String(localized: "display.seconds"))")
                    .fontWeight(.light)
            }
        }
    }

    // MARK: - Action buttons (edit / delete)

    private var actionButtons: some View {
        HStack {
            Button {
                AppDelegate.shared?.timerManager.testItem(item)
            } label: {
                Label("display.test", systemImage: "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Spacer()
            Button(action: startEditing) {
                Label("display.edit", systemImage: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                Label("display.delete", systemImage: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .alert("display.deleteReminder", isPresented: $showingDeleteConfirm) {
                Button("common.cancel", role: .cancel) {}
                Button("display.delete", role: .destructive) { store.delete(item) }
            } message: {
                Text("display.deleteConfirm \(customTitle)")
            }
        }
    }

    // MARK: - Edit form

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("display.title").font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                TextField("", text: $draftTitle).textFieldStyle(.roundedBorder)
            }
            HStack(alignment: .center) {
                Text("display.message").font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
//                TextField("", text: $draftMessage).textFieldStyle(.roundedBorder)
                TextEditor(text: $draftMessage)
                    .frame(height: 60)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color(nsColor: .separatorColor))
                    )
                    .overlay(alignment: .topLeading) {
                        if draftMessage.isEmpty {
                            Text("display.messagePlaceholder")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .allowsHitTesting(false)
                        }
                    }
            }
            // Lottie
            HStack(alignment: .top) {
                Text("display.animation").font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading).padding(.top, 4)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(action: chooseLottieFileForDraft) {
                            HStack { Image(systemName: "doc.badge.plus"); Text(draftLottieName.isEmpty ? String(localized: "display.chooseFile") : String(localized: "display.changeFile")) }
                        }
                        if !draftLottieName.isEmpty {
                            Button(action: { draftLottieName = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }.buttonStyle(.plain)
                        }
                        if !draftLottieName.isEmpty {
                            Text(draftLottieName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    previewBox(lottieName: draftLottieName.isEmpty ? nil : draftLottieName)
                }
            }
            HStack(alignment: .center) {
                Text("display.interval").font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                Spacer()
                TextField("", value: $draftInterval, format: .number).textFieldStyle(.roundedBorder).frame(width: 60)
                Stepper("", value: $draftInterval, in: 1...120, step: 1).labelsHidden()
                Text("display.min")
            }
            HStack(alignment: .center) {
                Text("display.duration").font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                Spacer()
                TextField("", value: $draftDuration, format: .number).textFieldStyle(.roundedBorder).frame(width: 60)
                Stepper("", value: $draftDuration, in: 5...60, step: 1).labelsHidden()
                Text("display.sec")
            }
        }
    }

    // MARK: - Save / Cancel

    private var saveCancelButtons: some View {
        HStack {
            Spacer()
            Button("common.cancel") { cancelEditing() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Button("common.save") { saveEditing() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func iconView(size: CGFloat) -> some View {
        let name = (rowState == .editing ? draftLottieName : (resolvedLottieName ?? ""))
        if let path = resolveMediaPath(for: name) {
            let type = MediaType.detect(for: path)
            if type == .lottie, let animation = LottieAnimation.filepath(path) {
                LottieView(animation: animation)
                    .configure { $0.contentMode = .scaleAspectFit }
                    .playbackMode(.playing(.fromProgress(nil, toProgress: 1, loopMode: .loop)))
                    .animationSpeed(1.0)
                    .frame(width: size, height: size)
            } else if type == .image {
                ScaledMediaImage(path: path, size: size, cornerRadius: 4)
            } else {
                bellIcon(size: size)
            }
        } else {
            bellIcon(size: size)
        }
    }

    private func bellIcon(size: CGFloat) -> some View {
        Image(systemName: "bell.fill")
            .font(.system(size: size * 0.5))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func previewBox(lottieName: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                .frame(width: 80, height: 80)
            if let name = lottieName, let path = resolveMediaPath(for: name) {
                let type = MediaType.detect(for: path)
                if type == .lottie, let animation = LottieAnimation.filepath(path) {
                    LottieView(animation: animation)
                        .configure { $0.contentMode = .scaleAspectFit }
                        .playbackMode(.playing(.fromProgress(nil, toProgress: 1, loopMode: .loop)))
                        .animationSpeed(1.0)
                        .frame(width: 64, height: 64)
                } else if type == .image {
                    ScaledMediaImage(path: path, size: 64, cornerRadius: 6)
                } else {
                    Text("display.noMedia").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("display.noMedia").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - State transitions

    private func startEditing() {
        draftTitle = customTitle
        draftMessage = customMessage
        draftInterval = intervalMinutes
        draftDuration = durationSeconds
        draftLottieName = customLottieName
        withAnimation(.easeInOut(duration: 0.2)) { rowState = .editing }
    }

    private func saveEditing() {
        customTitle = draftTitle
        customMessage = draftMessage
        intervalMinutes = draftInterval
        durationSeconds = draftDuration
        customLottieName = draftLottieName
        withAnimation(.easeInOut(duration: 0.2)) { rowState = .expanded }
    }

    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.2)) { rowState = .expanded }
    }

    private func chooseLottieFileForDraft() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "display.chooseMediaFile")
        panel.allowedContentTypes = [.json, .gif, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let lottieDir = appSupport.appendingPathComponent("notech/lottie", isDirectory: true)
        try? fm.createDirectory(at: lottieDir, withIntermediateDirectories: true)
        let destName = item.id + "_" + url.lastPathComponent
        do {
            let finalName = try copyAsIs(
                sourceURL: url, destDirectory: lottieDir, destName: destName)
            draftLottieName = finalName
        } catch {
            print("Failed to copy media file: \(error)")
        }
    }
}

// MARK: - Add Reminder Sheet

struct AddReminderSheet: View {
    let store: ReminderStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var message = ""
    @State private var intervalMinutes: Double = 45
    @State private var durationSeconds: Double = 20
    @State private var lottieFileName: String = ""

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("display.addReminder")
                    .font(.headline)

                // Title
                VStack(alignment: .leading) {
                    Text("display.title")
                    TextField(String(localized: "display.titlePlaceholder"),
                              text: $title,
                              axis: .vertical )
                        .textFieldStyle(.roundedBorder)
                    
                }

                // Message
                VStack(alignment: .leading) {
                    Text("display.message")
                    TextEditor(text: $message)
                        .font(.system(size: 13))
                        .frame(height: 60)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color(nsColor: .separatorColor))
                        )
                        .overlay(alignment: .topLeading) {
                            if message.isEmpty {
                                Text("display.messagePlaceholder")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                // Media
                VStack(alignment: .leading) {
                    Text("display.animation")
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: chooseLottieFile) {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                    Text(selectedLottieName == nil ? String(localized: "display.chooseFile") : String(localized: "display.changeFile"))
                                }
                            }
                            if selectedLottieName != nil {
                                Button(action: { lottieFileName = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            if let name = selectedLottieName {
                                Text(name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        // Preview
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                                .frame(width: 80, height: 80)
                            if let name = selectedLottieName, let path = resolveMediaPath(for: name) {
                                let type = MediaType.detect(for: path)
                                if type == .lottie, let animation = LottieAnimation.filepath(path) {
                                    LottieView(animation: animation)
                                        .configure { animatable in
                                            animatable.contentMode = .scaleAspectFit
                                        }
                                        .playbackMode(.playing(.fromProgress(nil, toProgress: 1, loopMode: .loop)))
                                        .animationSpeed(1.0)
                                        .frame(width: 64, height: 64)
                                } else if type == .image {
                                    ScaledMediaImage(path: path, size: 64, cornerRadius: 6)
                                } else {
                                    Text("display.noMedia")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("display.noMedia")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Interval
                HStack(alignment: .center) {
                    Text("display.interval")
                    Spacer()
                    TextField("", value: $intervalMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Stepper("", value: $intervalMinutes, in: 1...120, step: 1)
                        .labelsHidden()
                    Text("display.min")
                }

                // Duration
                HStack(alignment: .center) {
                    Text("display.duration")
                    Spacer()
                    TextField("", value: $durationSeconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Stepper("", value: $durationSeconds, in: 5...60, step: 1)
                        .labelsHidden()
                    Text("display.sec")
                }

                // Buttons
                HStack {
                    Spacer()
                    Button("common.cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Button("common.add") {
                        let newId = UUID().uuidString
                        let lottieName = lottieFileName.trimmingCharacters(in: .whitespaces).isEmpty
                            ? nil : lottieFileName.trimmingCharacters(in: .whitespaces)

                        let newItem = ReminderItem(
                            id: newId,
                            emoji: "",
                            title: title.isEmpty ? String(localized: "display.customReminderDefault") : title,
                            message: message.isEmpty ? String(localized: "display.defaultReminderMessage") : message,
                            intervalMinutes: intervalMinutes,
                            durationSeconds: durationSeconds,
                            lottieName: lottieName,
                            isBuiltIn: false
                        )
                        if let name = lottieName {
                            UserDefaults.standard.set(name, forKey: newItem.lottieKey)
                        }
                        store.add(newItem)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.isEmpty && message.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(24)
            .frame(width: 360)
        }
    }

    // MARK: - Lottie helpers

    private var selectedLottieName: String? {
        let name = lottieFileName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private func chooseLottieFile() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "display.chooseMediaFile")
        panel.allowedContentTypes = [.json, .gif, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let lottieDir = appSupport.appendingPathComponent("notech/lottie", isDirectory: true)
        try? fm.createDirectory(at: lottieDir, withIntermediateDirectories: true)

        let destName = UUID().uuidString + "_" + url.lastPathComponent
        do {
            let finalName = try copyAsIs(
                sourceURL: url, destDirectory: lottieDir, destName: destName)
            lottieFileName = finalName
        } catch {
            print("Failed to copy media file: \(error)")
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    @StateObject private var updateChecker = UpdateChecker()

    private var appVersionAndBuild: String {
        let version = Bundle.main
            .infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
        let build = Bundle.main
            .infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
        return "Version \(version) (\(build))"
    }

    private var copyright: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return "© \(year) Frank Lam "
    }

    private var developerWebsite: URL {
        URL(string: "https://www.hacomata.buzz/")!
    }
    
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image("AboutIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80)

            Text("NotchRoller")
                .font(.title)
                .fontWeight(.bold)

//            Text("about.version \(appVersion)")
//                .foregroundStyle(.secondary)

//            Text("about.description")
//                .multilineTextAlignment(.center)
//                .foregroundStyle(.secondary)
//                .padding(.horizontal, 40)
            
            VStack(spacing: 6) {
                Text(appVersionAndBuild)
                Text(copyright)
            }
            .font(.callout)
            Link(
                "Developer Website",
                destination: developerWebsite
            )
            .foregroundStyle(.indigo)

            // Check for updates
            HStack {
                Button("settings.general.checkForUpdates") {
                    updateChecker.checkForUpdates()
                }
                .disabled(updateChecker.isChecking)

                if updateChecker.isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .alert(
                updateChecker.updateAvailable
                    ? String(localized: "settings.general.updateAvailable")
                    : String(localized: "settings.general.upToDate"),
                isPresented: .init(
                    get: { !updateChecker.isChecking && updateChecker.latestVersion != nil },
                    set: { if !$0 { updateChecker.latestVersion = nil } }
                )
            ) {
                if updateChecker.updateAvailable,
                   let url = URL(string: updateChecker.latestReleaseUrl ?? "") {
                    Link("settings.general.download", destination: url)
                        .buttonStyle(.borderedProminent)
                }
                Button("common.ok") { updateChecker.latestVersion = nil }
            } message: {
                if updateChecker.updateAvailable {
                    Text("settings.general.newVersion \(updateChecker.latestVersion ?? "")")
                } else {
                    Text("settings.general.currentVersion \(updateChecker.currentVersion)")
                }
            }

            if let error = updateChecker.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
