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
        ZStack(alignment: .top) {
            if isPopupVisible {
                VStack(spacing: 0) {
                    contentViewContainer
                        .frame(width: CGFloat(expandedWidth), height: CGFloat(expandedHeight))
                        .offset(y: max(0, dragOffset/2))

                    Spacer(minLength: 0)

                    pullTab
                        .frame(width: CGFloat(expandedWidth), height: pullTabHeight)
                }
                .frame(width: CGFloat(expandedWidth), height: max(totalExpandedHeight, visibleHeight))
                .frame(width: visibleWidth, height: visibleHeight, alignment: .top)
                .background(
                    NotchShape(cornerRadius: popupCornerRadius, flareRadius: notchFlareRadius)
                        .fill(.black)
                )
                .clipShape(
                    NotchShape(cornerRadius: popupCornerRadius, flareRadius: notchFlareRadius)
                )
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
                    .opacity(previewOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            if previewing {
                panelProxy.panel?.alphaValue = 1
            } else if !timerManager.isExpanded {
                panelProxy.panel?.alphaValue = 0
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
                    let animSize = animation.size
                    LottieView(animation: animation)
                        .configure { animatable in
                            animatable.contentMode = .scaleAspectFit
                        }
                        .playbackMode(playLottie
                            ? .playing(.fromProgress(nil, toProgress: 1, loopMode: .loop))
                            : .pause)
                        .animationSpeed(1.0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else if type == .image {
                    ScaledMediaImage(path: mediaPath, cornerRadius: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            Text(item.resolvedMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
        }
        .padding(.vertical)
        .padding(.top)
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
                    updatePanelFrame(additionalHeight: dragOffset)
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
        updatePanelFrame()
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
        updatePanelFrame()
    }

    // MARK: - Panel Frame
    private func updatePanelFrame(additionalHeight: CGFloat = 0) {
        guard let screen = ScreenResolver.resolveTargetScreen() else { return }
        let sf = screen.frame
        let w = CGFloat(expandedWidth)
        let buffer: CGFloat = max(100, additionalHeight)
        let h = totalExpandedHeight + buffer

        let ox = sf.midX - w / 2
        let oy = sf.maxY - h

        panelProxy.popupFrame = NSRect(x: ox, y: oy, width: w, height: h)
        panelProxy.applyFrame()
    }
}
