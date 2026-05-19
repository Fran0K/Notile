# NotchRoller

macOS 菜单栏应用，在刘海区域以卷帘窗形式弹出定时提醒。

目标平台 macOS 15.7+，SwiftUI + CocoaPods（lottie-ios）。

## 架构图

```
NotchRollerApp (@main SwiftUI App)
│
├── MenuBarExtra ──────────────────── 菜单栏图标 + 菜单（设置/退出）
│
├── Settings ──────────────────────── SwiftUI Settings 窗口
│     └── SettingsView
│           ├── GeneralTab ─── 启动登录、免打扰、尺寸预览
│           ├── DisplayTab ─── 提醒项列表 + CRUD + 测试按钮
│           │     └── 通过 AppDelegate.shared.timerManager 访问核心
│           └── AboutTab ───── 版本信息
│
└── @NSApplicationDelegateAdaptor
      └── AppDelegate (static shared)
            │
            ├── TimerManager (@Observable @MainActor)
            │     ├── isExpanded / activeItemId ──── 当前展开状态
            │     ├── ReminderStore (@Observable) ── 提醒项数据
            │     ├── timers: [String: Timer] ────── 每项定时器
            │     ├── collapseTimer ──────────────── 自动收起定时器
            │     └── AnyCancellable × 2 ──────────── Combine 订阅
            │
            ├── PanelProxy ──────────── NotchView → NotchPanel 桥接
            │
            └── NotchPanel (NSPanel, .statusBar 层级)
                  └── PopupHitView (仅弹窗区域响应点击)
                        └── NSHostingView
                              └── NotchView
                                    ├── NotchShape ──── 刘海反圆角裁剪
                                    ├── LottieView ──── 动画播放
                                    └── ScaledMediaImage (GIF/图片)
```

## 新建数据流通过程

```
用户操作                    SettingsView                  TimerManager                 NotchView/Panel
─────────────────────────────────────────────────────────────────────────────────────────────────────────
1. 点击"添加提醒"
   │
   └──→ AddReminderSheet 弹出
         │
2. 填写标题/内容/动画
   │
   └──→ 点击"添加"按钮
         │
         ├──→ store.add(newItem)           ──→ @Observable 触发
         │     ├── items.append(newItem)          DisplayTab 重渲染
         │     └── save() → UserDefaults          新行出现在列表中
         │
         └──→ dismiss() 关闭 Sheet
               │
3. ~300ms 后 (debounce)           ──→ observeSettings 触发
                                     ├── stop() 清除所有旧定时器
                                     └── scheduleAllEnabled()
                                           └── 为 newItem 创建 Timer
                                                 │
4. 等待定时间隔 (如 45 分钟)       ←──── Timer 触发 ───────┘
   │
   └──→ expand(item)                           ──→ isExpanded = true
         │                                           │
         ├── activeItemId = item.id                   ├── .onChange(isExpanded) 触发
         ├── .notchRollerDidExpand 通知               ├── expandAnimation() 弹簧动画
         └── collapseTimer 启动                       └── panel.alphaValue = 1
               │                                           │
5. 显示 duration 秒后 (如 20 秒)                        │ ← 内容可见
   │                                                     │
   └──→ collapseTimer 触发                        ←──────┘
         │
         └──→ collapse()                       ──→ isExpanded = false
               ├── .notchRollerDidCollapse 通知       ├── collapseAnimation()
               └── rescheduleItem()                   └── panel.alphaValue = 0
                     └── 重新设置下一轮定时器
```

## 手动测试流程

```
用户点击"测试"按钮 (ReminderConfigRow)
  │
  └──→ AppDelegate.shared.timerManager.testItem(item)    ← 直接方法调用，@MainActor 安全
        │
        ├── guard isEnabled(item)                        ← 检查是否启用
        │
        ├── 当前已展开？
        │     ├── YES → 先 collapse → 等 0.5s → expand(item)
        │     └── NO  → 直接 expand(item)
        │
        └──→ expand(item)                                ← 同上展开流程
```

## 关键设计

| 主题 | 方案 |
|------|------|
| 状态管理 | `@Observable` + `@Bindable`，isExpanded 驱动动画 |
| 动画 | `withAnimation(.spring(...))` 修改 @State，卷帘从中心发散 |
| 面板定位 | 始终用 `NSScreen.screens.first`（主屏/刘海屏），避免外接显示器偏移 |
| 数据持久化 | `ReminderStore` → `JSONEncoder` → `UserDefaults` |
| 媒体存储 | App Support `notech/lottie/` 目录，导入时自动压缩缩略图 |
| 跨场景通信 | `AppDelegate.shared` 静态引用（`@NSApplicationDelegateAdaptor` 包装后 `NSApp.delegate` 无法直接 cast） |
| 面板交互 | `PopupHitView.hitTest()` 仅在 popupFrame 内响应，其余区域鼠标穿透 |

## 文件说明

| 文件 | 职责 |
|------|------|
| `notchEyeApp.swift` | @main 入口，MenuBarExtra 菜单 + Settings 场景 |
| `AppDelegate.swift` | 创建 NotchPanel，管理面板显隐，屏幕参数变化监听 |
| `TimerManager.swift` | 核心调度：定时器、展开/收起、静默时段、通知观察 |
| `NotchView.swift` | 主视图：卷帘动画、拖拽手势、内容渲染、尺寸预览 |
| `NotchShape.swift` | 自定义 Shape：顶部反圆角贴合刘海、底部正常圆角 |
| `NotchPanel.swift` | NSPanel 子类：全屏透明、PopupHitView 区域点击 |
| `PanelProxy.swift` | NotchView → NotchPanel 的 hit-test 区域桥接 |
| `SettingsView.swift` | 设置界面：CRUD、自定义、媒体管理、测试按钮 |
| `ReminderType.swift` | 数据模型 ReminderItem + ReminderStore 持久化 |
| `MediaHelpers.swift` | 媒体工具：类型检测、路径解析、图片缩略图 |
