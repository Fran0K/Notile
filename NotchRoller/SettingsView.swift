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
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            DisplayTab()
                .tabItem { Label("Display", systemImage: "eye") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 550)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @AppStorage("expandedWidth") private var expandedWidth: Double = 300
    @AppStorage("expandedHeight") private var expandedHeight: Double = 120
    @AppStorage("isPreviewing") private var isPreviewing: Bool = false
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    @AppStorage("quietHoursEnabled") private var quietHoursEnabled: Bool = false
    @AppStorage("quietStartHour") private var quietStartHour: Double = 22
    @AppStorage("quietEndHour") private var quietEndHour: Double = 8
    @AppStorage("allDayQuiet") private var allDayQuiet: Bool = false
    @AppStorage("respectDND") private var respectDND: Bool = true
    @AppStorage("respectMeeting") private var respectMeeting: Bool = true

    private var screenSize: CGSize {
        NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
        Form {
            Section("Launch") {
                Toggle("Start at Login", isOn: $launchAtLogin)
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

            Section("Quiet Hours") {
                Toggle("启用免打扰时段", isOn: $quietHoursEnabled)

                if quietHoursEnabled {
                    HStack(alignment: .center) {
                        Text("开始")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                        Picker("", selection: $quietStartHour) {
                            ForEach(Array(stride(from: 0, to: 24, by: 0.5)), id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                        .disabled(allDayQuiet)
                    }

                    HStack(alignment: .center) {
                        Text("结束")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                        Picker("", selection: $quietEndHour) {
                            ForEach(Array(stride(from: 0, to: 24, by: 0.5)), id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                        .disabled(allDayQuiet)
                    }

                    Toggle("All Day", isOn: $allDayQuiet)

                    if allDayQuiet {
                        Text("已启用全天免打扰，将不会弹出任何提醒")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Do Not Disturb") {
                Toggle("尊重免打扰模式", isOn: $respectDND)
                if respectDND {
                    Text("当系统开启免打扰时，暂停提醒")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("尊重会议模式", isOn: $respectMeeting)
                if respectMeeting {
                    Text("当检测到日历中的会议时，暂停提醒")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("SIZE") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Expand Size")
                            .fontWeight(.bold)
                        Text("Dimensions of the expanded view")
                            .font(.body)
                    }
                    Spacer()
                }.padding()

                HStack(alignment: .center) {
                    VStack(alignment: .center, spacing: 4) {
                        Text("Width")
                            .fontWeight(.bold)
                        Text("\(Int(expandedWidth)) pt")
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
                        Text("Height")
                            .fontWeight(.bold)
                        Text("\(Int(expandedHeight)) pt")
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
                        Text("添加提醒")
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
//            HStack {
//                Text("标题")
//                    .frame(width: 70, alignment: .leading)
//                Text(customTitle)
//                Spacer()
//            }
//            HStack {
//                Text("内容")
//                    .frame(width: 70, alignment: .leading)
//                Text(customMessage)
//                Spacer()
//            }
//            HStack {
//                Text("动画")
//                    .frame(width: 70, alignment: .leading)
//                if let name = resolvedLottieName {
//                    iconView(size: 40)
//                        .frame(width: 45, height: 45)
//                } else {
//                    Text("无").font(.caption).foregroundStyle(.secondary)
//                }
//                Spacer()
//            }
            HStack(spacing: 4) {
                Text("间隔：")
                Text("\(Int(intervalMinutes)) 分钟")
                Spacer()
                Text("时长：")
                Text("\(Int(durationSeconds)) 秒")
            }
//            HStack {
//                
//                Spacer()
//            }
        }
    }

    // MARK: - Action buttons (edit / delete)

    private var actionButtons: some View {
        HStack {
            Button {
                AppDelegate.shared?.timerManager.testItem(item)
            } label: {
                Label("测试", systemImage: "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Spacer()
            Button(action: startEditing) {
                Label("编辑", systemImage: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                Label("删除", systemImage: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .alert("删除提醒", isPresented: $showingDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) { store.delete(item) }
            } message: {
                Text("确定要删除「\(customTitle)」吗？")
            }
        }
    }

    // MARK: - Edit form

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("标题").font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                TextField("", text: $draftTitle).textFieldStyle(.roundedBorder)
            }
            HStack(alignment: .center) {
                Text("内容").font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                TextField("", text: $draftMessage).textFieldStyle(.roundedBorder)
            }
            // Lottie
            HStack(alignment: .top) {
                Text("动画").font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading).padding(.top, 4)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(action: chooseLottieFileForDraft) {
                            HStack { Image(systemName: "doc.badge.plus"); Text(draftLottieName.isEmpty ? "选择文件" : "更换文件") }
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
                Text("间隔").font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                Spacer()
                TextField("", value: $draftInterval, format: .number).textFieldStyle(.roundedBorder).frame(width: 60)
                Stepper("", value: $draftInterval, in: 1...120, step: 1).labelsHidden()
                Text("Min")
            }
            HStack(alignment: .center) {
                Text("时长").font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                Spacer()
                TextField("", value: $draftDuration, format: .number).textFieldStyle(.roundedBorder).frame(width: 60)
                Stepper("", value: $draftDuration, in: 5...60, step: 1).labelsHidden()
                Text("S")
            }
        }
    }

    // MARK: - Save / Cancel

    private var saveCancelButtons: some View {
        HStack {
            Spacer()
            Button("取消") { cancelEditing() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Button("保存") { saveEditing() }
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
                    Text("无媒体").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("无媒体").font(.caption).foregroundStyle(.secondary)
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
        panel.title = "选择媒体文件"
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
                Text("添加提醒")
                    .font(.headline)

                // Title
                VStack(alignment: .leading) {
                    Text("标题")
                    TextField("提醒标题", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                // Message
                VStack(alignment: .leading) {
                    Text("内容")
                    TextField("提醒内容", text: $message)
                        .textFieldStyle(.roundedBorder)
                }

                // Media
                VStack(alignment: .leading) {
                    Text("动画")
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: chooseLottieFile) {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                    Text(selectedLottieName == nil ? "选择文件" : "更换文件")
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
                                    Text("无媒体")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("无媒体")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Interval
                HStack(alignment: .center) {
                    Text("间隔")
                    Spacer()
                    TextField("", value: $intervalMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Stepper("", value: $intervalMinutes, in: 1...120, step: 1)
                        .labelsHidden()
                    Text("Min")
                }

                // Duration
                HStack(alignment: .center) {
                    Text("时长")
                    Spacer()
                    TextField("", value: $durationSeconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Stepper("", value: $durationSeconds, in: 5...60, step: 1)
                        .labelsHidden()
                    Text("S")
                }

                // Buttons
                HStack {
                    Spacer()
                    Button("取消") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Button("添加") {
                        let newId = UUID().uuidString
                        let lottieName = lottieFileName.trimmingCharacters(in: .whitespaces).isEmpty
                            ? nil : lottieFileName.trimmingCharacters(in: .whitespaces)

                        let newItem = ReminderItem(
                            id: newId,
                            emoji: "",
                            title: title.isEmpty ? "自定义提醒" : title,
                            message: message.isEmpty ? "该休息一下了" : message,
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
        panel.title = "选择媒体文件"
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
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image("AboutIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)

            Text("NotchRoller")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(appVersion)")
                .foregroundStyle(.secondary)

            Text("一款基于刘海区域的护眼提醒工具\n定时提醒你休息眼睛、喝水、活动身体")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
