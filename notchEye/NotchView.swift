//import SwiftUI
//import Lottie
//
//struct NotchView: View {
//    @Bindable var timerManager: TimerManager
//    let panelProxy: PanelProxy
//
//    @AppStorage("expandedWidth") private var expandedWidth: Double = 300
//    @AppStorage("expandedHeight") private var expandedHeight: Double = 120
//    @AppStorage("isPreviewing") private var isPreviewing: Bool = false
//
//    // MARK: - Animation State
//    // 新增独立可见性控制，防止视图在动画期间被 SwiftUI 提前移除
//    @State private var isPopupVisible: Bool = false
//    
//    @State private var animWidth: CGFloat = 0
//    @State private var animHeight: CGFloat = 0
//    @State private var contentOpacity: Double = 0
//    @State private var playLottie: Bool = false
//
//    // MARK: - Drag State
//    @State private var dragOffset: CGFloat = 0
//    @State private var isDragging: Bool = false
//    @State private var isAnimatingCollapse: Bool = false
//
//    // Preview state
//    @State private var previewOpacity: Double = 0
//
//    private let pullTabHeight: CGFloat = 20
//    private let popupCornerRadius: CGFloat = 20
//
//    // MARK: - Computed
//
//    /// 完整展开的高度 (内容 + 底部把手)
//    private var totalExpandedHeight: CGFloat { CGFloat(expandedHeight) + pullTabHeight }
//
//    /// 当前实际显示的宽度
//    private var visibleWidth: CGFloat {
//        max(0, animWidth)
//    }
//
//    /// 当前实际显示的高度（加上拖拽偏移量）
//    private var visibleHeight: CGFloat {
//        max(0, animHeight + dragOffset)
//    }
//
//    // MARK: - Body
//
//    var body: some View {
//        GeometryReader { geo in
//            let centerX = geo.size.width / 2
//
//            ZStack(alignment: .top) {
//                // Popup (Center-Diverging Roller Blind)
//                if isPopupVisible {
//                    // 1. 内部始终保持完整的最终尺寸
//                    VStack(spacing: 0) {
//                        contentViewContainer
//                            .frame(width: CGFloat(expandedWidth), height: CGFloat(expandedHeight))
//                        
//                        pullTab
//                            .frame(width: CGFloat(expandedWidth), height: pullTabHeight)
//                    }
//                    .frame(width: CGFloat(expandedWidth), height: totalExpandedHeight) // 固定内容画板
//                    // 2. 动态外框，底部对齐。配合 clipShape 形成完美的“拉/卷卷帘”效果
//                    .frame(width: visibleWidth, height: visibleHeight, alignment: .bottom)
//                    .background(
//                        RoundedRectangle(cornerRadius: popupCornerRadius)
//                            .fill(.black)
//                    )
//                    // 切掉多余部分并保持圆角跟随外框收缩
//                    .clipShape(RoundedRectangle(cornerRadius: popupCornerRadius))
//                    // 3. 始终锚定在顶部 (Notch 位置中心)
//                    .position(x: centerX, y: visibleHeight / 2)
//                    .gesture(dragGesture)
//                }
//
//                // Preview overlay (for settings)
//                if isPreviewing {
//                    RoundedRectangle(cornerRadius: popupCornerRadius)
//                        .fill(.black.opacity(0.3))
//                        .frame(width: CGFloat(expandedWidth), height: CGFloat(expandedHeight))
//                        .overlay {
//                            Text("\(Int(expandedWidth)) × \(Int(expandedHeight))")
//                                .font(.system(size: 14, weight: .medium))
//                                .foregroundStyle(.white.opacity(0.8))
//                        }
//                        .position(x: centerX, y: CGFloat(expandedHeight) / 2)
//                        .opacity(previewOpacity)
//                }
//            }
//        }
//        .onAppear {
//            updatePanelFrame()
//        }
//        .onChange(of: timerManager.isExpanded) { _, isExpanded in
//            if isExpanded {
//                isPopupVisible = true
//                updatePanelFrame()
//                expandAnimation()
//            } else if !isExpanded && !isAnimatingCollapse && isPopupVisible {
//                collapseAnimation()
//            }
//        }
//        .onChange(of: isPreviewing) { _, previewing in
//            withAnimation(.easeInOut(duration: 0.2)) {
//                previewOpacity = previewing ? 1 : 0
//            }
//        }
//        .onChange(of: expandedWidth) { _, _ in updatePanelFrame() }
//        .onChange(of: expandedHeight) { _, _ in updatePanelFrame() }
//    }
//
//    // MARK: - Content
//
//    private var contentViewContainer: some View {
//        Group {
//            if let item = timerManager.activeItem() {
//                contentView(for: item)
//                    .opacity(contentOpacity)
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//
//    @ViewBuilder
//    private func contentView(for item: ReminderItem) -> some View {
//        VStack(spacing: 6) {
//            if let mediaName = item.resolvedLottieName,
//               let mediaPath = resolveMediaPath(for: mediaName) {
//                let type = MediaType.detect(for: mediaPath)
//                if type == .lottie, let animation = LottieAnimation.filepath(mediaPath) {
//                    LottieView(animation: animation)
//                        .configure { animatable in
//                            animatable.contentMode = .scaleAspectFit
//                        }
//                        .playbackMode(playLottie
//                            ? .playing(.fromProgress(nil, toProgress: 1, loopMode: .loop))
//                            : .pause)
//                        .animationSpeed(1.0)
//                        .frame(width: 56, height: 56)
//                } else if type == .image {
//                    ScaledMediaImage(path: mediaPath, size: 56, cornerRadius: 8)
//                } else {
//                    fallbackText(item)
//                }
//            } else {
//                fallbackText(item)
//            }
//            Text(item.resolvedMessage)
//                .font(.system(size: 14, weight: .medium))
//                .foregroundStyle(.white)
//        }
//    }
//
//    private func fallbackText(_ item: ReminderItem) -> some View {
//        Text(String(item.resolvedTitle.prefix(1)))
//            .font(.system(size: 36, weight: .bold))
//            .foregroundStyle(.white)
//    }
//
//    // MARK: - Pull Tab
//
//    @State private var isHoveringPullTab: Bool = false
//
//    private var pullTab: some View {
//        VStack(spacing: 4) {
//            Capsule()
//                .fill(Color.white.opacity(isHoveringPullTab ? 0.6 : 0.4))
//                .frame(width: 36, height: 5)
//                .padding(.top, 4)
//            Spacer()
//        }
//        .frame(maxWidth: .infinity)
//        .contentShape(Rectangle())
//        .onHover { hovering in
//            withAnimation(.easeInOut(duration: 0.15)) {
//                isHoveringPullTab = hovering
//            }
//        }
//    }
//
//    // MARK: - Drag Gesture
//
//    private var dragGesture: some Gesture {
//        DragGesture(minimumDistance: 5, coordinateSpace: .local)
//            .onChanged { value in
//                if !isDragging {
//                    isDragging = true
//                    timerManager.cancelCollapseTimer()
//                }
//                dragOffset = value.translation.height
//                
//                // 向上推时稍微变淡，但下拉时保持不透明
//                if dragOffset < 0 {
//                    let progress = -dragOffset / totalExpandedHeight
//                    contentOpacity = Double(max(0, 1 - progress))
//                } else {
//                    contentOpacity = 1
//                }
//            }
//            .onEnded { _ in
//                isDragging = false
//                if dragOffset > totalExpandedHeight * 0.15 {
//                    // 下拉释放，模拟卷帘触底反弹收回
//                    completeCollapseFromDrag()
//                } else if dragOffset < -totalExpandedHeight * 0.3 {
//                    // 向上推过头，直接收回
//                    completeCollapseFromDrag()
//                } else {
//                    // 拖拽幅度不够：Q弹回位
//                    snapBack()
//                }
//            }
//    }
//
//    // MARK: - Animations
//
//    private func expandAnimation() {
//        playLottie = true
//        
//        // 初始化起点（从 0x0 中心点开始）
//        animWidth = 0
//        animHeight = 0
//        contentOpacity = 0
//        dragOffset = 0
//        
//        // 弹簧动画：往下展现卷帘的同时往两边发散
//        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
//            animWidth = CGFloat(expandedWidth)
//            animHeight = totalExpandedHeight
//            contentOpacity = 1
//        }
//    }
//
//    private func collapseAnimation() {
//        playLottie = false
//        
//        // 核心修改：收起时我们不再让 opacity 变 0，让用户看到它实体缩成一个点回滚到 Notch
//        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
//            animWidth = 0
//            animHeight = 0
//        } completion: {
//            // 只有当尺寸物理缩小到 0 之后，才移除视图
//            isPopupVisible = false
//            contentOpacity = 0 // 为下一次做重置准备
//        }
//    }
//
//    private func completeCollapseFromDrag() {
//        isAnimatingCollapse = true
//        
//        // 吸收 dragOffset，从用户手松开的位置直接开始弹簧收回动画
//        animHeight = max(0, animHeight + dragOffset)
//        dragOffset = 0
//        
//        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
//            animHeight = 0
//            animWidth = 0
//        } completion: {
//            // 动画彻底结束后触发通知并隐藏
//            timerManager.collapseFromDrag()
//            isAnimatingCollapse = false
//            isPopupVisible = false
//            contentOpacity = 0
//        }
//    }
//
//    private func snapBack() {
//        // 放手没到位时的回位动画
//        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
//            dragOffset = 0
//            contentOpacity = 1
//        }
//    }
//
//    // MARK: - Panel Frame
//
//    private func updatePanelFrame() {
//        guard let screen = NSScreen.main else { return }
//        let sf = screen.frame
//        
//        let w = CGFloat(expandedWidth)
//        let maxStretchBuffer: CGFloat = 60 // 预留一点下拉弹簧拉伸的空间
//        let h = totalExpandedHeight + maxStretchBuffer
//        
//        let ox = sf.midX - w / 2
//        let oy = sf.maxY - h // 保持 window 顶部严格贴合屏幕顶部(Notch)
//        
//        panelProxy.popupFrame = NSRect(x: ox, y: oy, width: w, height: h)
//    }
//}

import SwiftUI
import Lottie

// MARK: - 主视图
struct NotchView: View {
    @Bindable var timerManager: TimerManager
    let panelProxy: PanelProxy

    @AppStorage("expandedWidth") private var expandedWidth: Double = 300
    @AppStorage("expandedHeight") private var expandedHeight: Double = 120
    @AppStorage("isPreviewing") private var isPreviewing: Bool = false

    // Animation State
    @State private var isPopupVisible: Bool = false
    @State private var animWidth: CGFloat = 0
    @State private var animHeight: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var playLottie: Bool = false

    // Drag State
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isAnimatingCollapse: Bool = false

    // Preview state
    @State private var previewOpacity: Double = 0

    // Notch 专属参数配置
    private let pullTabHeight: CGFloat = 20
    private let popupCornerRadius: CGFloat = 20
    private let notchFlareRadius: CGFloat = 16

    // Computed
    private var totalExpandedHeight: CGFloat { CGFloat(expandedHeight) + pullTabHeight }
    private var visibleWidth: CGFloat { max(0, animWidth) }
    private var visibleHeight: CGFloat { max(0, animHeight + dragOffset) }

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2

            ZStack(alignment: .top) {
                if isPopupVisible {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        contentViewContainer
                            .frame(width: CGFloat(expandedWidth), height: CGFloat(expandedHeight))
                        
                        // 🌟 核心修复点 1：加入 Spacer()
                        // 当往下拉时，它会吸收掉多余的高度，确保上面的内容死死贴紧顶部
                        Spacer(minLength: 0)
                        
                        pullTab
                            .frame(width: CGFloat(expandedWidth), height: pullTabHeight)
                    }
                    // 🌟 核心修复点 2：高度取最大值
                    // 正常状态下是 totalExpandedHeight，下拉时动态拉伸
                    .frame(width: CGFloat(expandedWidth), height: max(totalExpandedHeight, visibleHeight))
                    
                    // 3. 动态外框，底部对齐，负责动画时的卷帘裁切
                    .frame(width: visibleWidth, height: visibleHeight, alignment: .bottom)
                    // 4. 背景和裁切都放到外框上，这样拉伸时背景也能无缝跟随延伸
                    .background(
                        NotchShape(cornerRadius: popupCornerRadius, flareRadius: notchFlareRadius)
                            .fill(.black)
                    )
                    .clipShape(
                        NotchShape(cornerRadius: popupCornerRadius, flareRadius: notchFlareRadius)
                    )
                    .position(x: centerX, y: visibleHeight / 2) // 永远将顶部锚点计算为 0
                    .gesture(dragGesture)
                }

                if isPreviewing {
                    NotchShape(cornerRadius: popupCornerRadius, flareRadius: notchFlareRadius)
                        .fill(.black.opacity(0.3))
                        .frame(width: CGFloat(expandedWidth), height: CGFloat(expandedHeight))
                        .overlay {
                            Text("\(Int(expandedWidth)) × \(Int(expandedHeight))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .position(x: centerX, y: CGFloat(expandedHeight) / 2)
                        .opacity(previewOpacity)
                }
            }
        }
        .onAppear {
            updatePanelFrame()
        }
        .onChange(of: timerManager.isExpanded) { _, isExpanded in
            if isExpanded {
                isPopupVisible = true
                updatePanelFrame()
                expandAnimation()
            } else if !isExpanded && !isAnimatingCollapse && isPopupVisible {
                collapseAnimation()
            }
        }
        .onChange(of: isPreviewing) { _, previewing in
            withAnimation(.easeInOut(duration: 0.2)) {
                previewOpacity = previewing ? 1 : 0
            }
        }
        .onChange(of: expandedWidth) { _, _ in updatePanelFrame() }
        .onChange(of: expandedHeight) { _, _ in updatePanelFrame() }
    }

    // MARK: - Content
    private var contentViewContainer: some View {
        Group {
            if let item = timerManager.activeItem() {
                contentView(for: item)
                    .opacity(contentOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func contentView(for item: ReminderItem) -> some View {
        VStack(spacing: 6) {
            if let mediaName = item.resolvedLottieName,
               let mediaPath = resolveMediaPath(for: mediaName) {
                let type = MediaType.detect(for: mediaPath)
                if type == .lottie, let animation = LottieAnimation.filepath(mediaPath) {
                    LottieView(animation: animation)
                        .configure { animatable in
                            animatable.contentMode = .scaleAspectFit
                        }
                        .playbackMode(playLottie
                            ? .playing(.fromProgress(nil, toProgress: 1, loopMode: .loop))
                            : .pause)
                        .animationSpeed(1.0)
                        .frame(width: 56, height: 56)
                } else if type == .image {
                    ScaledMediaImage(path: mediaPath, size: 56, cornerRadius: 8)
                } else {
                    fallbackText(item)
                }
            } else {
                fallbackText(item)
            }
            Text(item.resolvedMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private func fallbackText(_ item: ReminderItem) -> some View {
        Text(String(item.resolvedTitle.prefix(1)))
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(.white)
    }

    // MARK: - Pull Tab
    @State private var isHoveringPullTab: Bool = false

    private var pullTab: some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(Color.white.opacity(isHoveringPullTab ? 0.6 : 0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringPullTab = hovering
            }
        }
    }

    // MARK: - Drag Gesture
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .local)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    timerManager.cancelCollapseTimer()
                }
                dragOffset = value.translation.height
                
                if dragOffset < 0 {
                    let progress = -dragOffset / totalExpandedHeight
                    contentOpacity = Double(max(0, 1 - progress))
                } else {
                    contentOpacity = 1
                }
            }
            .onEnded { _ in
                isDragging = false
                if dragOffset > totalExpandedHeight * 0.15 {
                    completeCollapseFromDrag()
                } else if dragOffset < -totalExpandedHeight * 0.3 {
                    completeCollapseFromDrag()
                } else {
                    snapBack()
                }
            }
    }

    // MARK: - Animations
    private func expandAnimation() {
        playLottie = true
        animWidth = 0
        animHeight = 0
        contentOpacity = 0
        dragOffset = 0
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            animWidth = CGFloat(expandedWidth)
            animHeight = totalExpandedHeight
            contentOpacity = 1
        }
    }

    private func collapseAnimation() {
        playLottie = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            animWidth = 0
            animHeight = 0
        } completion: {
            isPopupVisible = false
            contentOpacity = 0
        }
    }

    private func completeCollapseFromDrag() {
        isAnimatingCollapse = true
        animHeight = max(0, animHeight + dragOffset)
        dragOffset = 0
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            animHeight = 0
            animWidth = 0
        } completion: {
            timerManager.collapseFromDrag()
            isAnimatingCollapse = false
            isPopupVisible = false
            contentOpacity = 0
        }
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            dragOffset = 0
            contentOpacity = 1
        }
    }

    // MARK: - Panel Frame
    private func updatePanelFrame() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.frame
        let w = CGFloat(expandedWidth)
        let maxStretchBuffer: CGFloat = 100
        let h = totalExpandedHeight + maxStretchBuffer
        
        let ox = sf.midX - w / 2
        let oy = sf.maxY - h
        
        panelProxy.popupFrame = NSRect(x: ox, y: oy, width: w, height: h)
    }
}
