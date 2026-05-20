# NotchRoller

macOS 菜单栏应用，在刘海区域以卷帘窗形式弹出定时提醒。

目标平台 macOS 15.7+，SwiftUI + CocoaPods（lottie-ios）。

## 功能特点

- **卷帘窗动画** — 提醒以卷帘形式从刘海区域展开/收起，使用弹簧动画，视觉效果流畅自然
- **多提醒管理** — 支持多个独立提醒项，每个可单独配置间隔时间、显示时长、动画/图片
- **内置提醒** — 预设护眼休息、喝水、活动身体三项提醒，开箱即用
- **自定义提醒** — 添加自定义标题、内容、间隔、时长，支持导入 Lottie 动画 / GIF / 静态图片
- **启用时段** — 可限定提醒仅在指定时间段内弹出（如 08:00–22:00），默认全天启用
- **展开尺寸预览** — 设置界面实时预览刘海弹窗的宽高效果
- **多语言支持** — 支持中文、英文、法语、日语，默认跟随系统语言，切换即时生效
- **登录自启** — 支持设置开机自动启动（SMAppService）
- **媒体管理** — 提醒可绑定 Lottie JSON / GIF / PNG 等媒体文件，无媒体时显示 emoji 首字母
- **测试按钮** — 每个提醒项可一键测试预览弹窗效果

## 架构图

```
NotchRollerApp (@main SwiftUI App)
│
├── MenuBarExtra ──────────────────── 菜单栏图标 + 菜单（设置/退出）
│
├── Settings ──────────────────────── SwiftUI Settings 窗口 (.thinMaterial 背景)
│     └── SettingsView
│           ├── GeneralTab ─── 语言、启动登录、启用时段、尺寸预览
│           ├── ItemsTab ──── 提醒项列表 + CRUD + 测试按钮
│           │     └── 通过 AppDelegate.shared.timerManager 访问核心
│           └── AboutTab ───── 版本信息 + 开发者链接
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
                              └── NotchViewLocaleWrapper (.environment locale)
                                    └── NotchView
                                          ├── NotchShape ──── 刘海反圆角裁剪
                                          ├── LottieView ──── 动画播放
                                          └── ScaledMediaImage (GIF/图片)
```

## 数据流

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

## 关键设计

| 主题 | 方案 |
|------|------|
| 状态管理 | `@Observable` + `@Bindable`，isExpanded 驱动动画 |
| 动画 | `withAnimation(.spring(...))` 修改 @State，卷帘从中心发散 |
| 面板定位 | 始终用 `NSScreen.screens.first`（主屏/刘海屏），避免外接显示器偏移 |
| 数据持久化 | `ReminderStore` → `JSONEncoder` → `UserDefaults` |
| 媒体存储 | App Support `notech/lottie/` 目录，导入时自动压缩缩略图 |
| 国际化 | String Catalog (`.xcstrings`)，`@AppStorage("appLanguage")` + `.environment(\.locale)` 即时切换 |
| 跨场景通信 | `AppDelegate.shared` 静态引用（`@NSApplicationDelegateAdaptor` 包装后 `NSApp.delegate` 无法直接 cast） |
| 面板交互 | `PopupHitView.hitTest()` 仅在 popupFrame 内响应，其余区域鼠标穿透 |
| 启用时段 | 反转免打扰逻辑：设置生效时间段，默认全天；`isOutsideActiveHours` 判断 |

## 文件说明

| 文件 | 职责 |
|------|------|
| `NotchRollerApp.swift` | @main 入口，MenuBarExtra 菜单 + Settings 场景 + locale 注入 |
| `AppDelegate.swift` | 创建 NotchPanel，管理面板显隐，NotchViewLocaleWrapper 传递 locale |
| `TimerManager.swift` | 核心调度：定时器、展开/收起、启用时段判断、通知观察 |
| `NotchView.swift` | 主视图：卷帘动画、拖拽手势、内容渲染、尺寸预览 |
| `NotchShape.swift` | 自定义 Shape：顶部反圆角贴合刘海、底部正常圆角 |
| `NotchPanel.swift` | NSPanel 子类：全屏透明、PopupHitView 区域点击 |
| `PanelProxy.swift` | NotchView → NotchPanel 的 hit-test 区域桥接 |
| `SettingsView.swift` | 设置界面：语言、启用时段、CRUD、媒体管理、测试按钮 |
| `ReminderType.swift` | 数据模型 ReminderItem + ReminderStore 持久化 |
| `MediaHelpers.swift` | 媒体工具：类型检测、路径解析、图片缩略图 |
| `AppLanguage.swift` | 语言枚举：locale 映射、显示名称 |
| `Localizable.xcstrings` | String Catalog：中/英/法/日四语翻译 |

## 更新策略

- 内置 item 使用固定 ID（`eyeRest` / `drinkWater` / `walkAround`），升级时不会覆盖用户自定义设置
- `ReminderStore.load()` 在已有数据时保留所有用户 item，仅追加新增内置 item
- 用户媒体文件存储在 Application Support 目录，独立于 app bundle，更新不受影响
- UserDefaults key 格式 `reminder_{id}_*` 保持不变，确保版本兼容
