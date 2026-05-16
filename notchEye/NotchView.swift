import SwiftUI
import Lottie

struct NotchView: View {
    @Bindable var timerManager: TimerManager
    let panelProxy: PanelProxy

    @AppStorage("expandedWidth") private var expandedWidth: Double = 300
    @AppStorage("expandedHeight") private var expandedHeight: Double = 120
    @AppStorage("isPreviewing") private var isPreviewing: Bool = false

    // Animation state
    @State private var currentHeight: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var playLottie: Bool = false

    // Drag state
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isAnimatingCollapse: Bool = false

    // Slide animation offset (positive = below target, negative = above target)
    @State private var yOffset: CGFloat = 0

    // Preview state
    @State private var previewOpacity: Double = 0

    private let pullTabHeight: CGFloat = 20
    private let popupCornerRadius: CGFloat = 20

    // MARK: - Computed

    /// Total height including pull tab
    private var totalExpandedHeight: CGFloat { CGFloat(expandedHeight) + pullTabHeight }

    /// Width that narrows when height < 50%
    private var visibleWidth: CGFloat {
        let ratio = min(1, visibleHeight / (CGFloat(expandedHeight) * 0.5))
        return CGFloat(expandedWidth) * ratio
    }

    /// Actual visible height: extends down when pulling, shrinks up when pushing
    private var visibleHeight: CGFloat {
        max(0, currentHeight + dragOffset)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2

            ZStack {
                // Popup (roller blind)
                if currentHeight > 0 {
                    let vH = visibleHeight
                    let vW = visibleWidth

                    VStack(spacing: 0) {
                        // Content area
                        contentViewContainer
                            .frame(width: vW, height: max(0, vH - pullTabHeight))
                            .clipped()

                        // Pull tab
                        pullTab
                            .frame(width: vW, height: pullTabHeight)
                    }
                    .frame(width: vW, height: vH)
                    .background(
                        RoundedRectangle(cornerRadius: popupCornerRadius)
                            .fill(.black)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: popupCornerRadius))
                    .position(x: centerX, y: vH / 2 + yOffset)
                    .gesture(dragGesture)
                }

                // Preview overlay (for settings)
                if isPreviewing {
                    RoundedRectangle(cornerRadius: popupCornerRadius)
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
        .onChange(of: timerManager.isExpanded) { _, isExpanded in
            if isExpanded && currentHeight == 0 {
                expandAnimation()
            } else if !isExpanded && currentHeight > 0 && !isAnimatingCollapse {
                collapseAnimation()
            }
        }
        .onChange(of: isPreviewing) { _, previewing in
            withAnimation(.easeInOut(duration: 0.2)) {
                previewOpacity = previewing ? 1 : 0
            }
        }
        .onChange(of: currentHeight) { _, _ in updatePanelFrame() }
        .onChange(of: expandedWidth) { _, _ in updatePanelFrame() }
        .onChange(of: yOffset) { _, _ in updatePanelFrame() }
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
                // Positive = pull down (extend), negative = push up (shrink)
                dragOffset = max(-currentHeight, value.translation.height)
                // Fade content when pushing up
                if dragOffset < 0 {
                    let progress = -dragOffset / currentHeight
                    contentOpacity = Double(max(0, 1 - progress))
                } else {
                    contentOpacity = 1
                }
            }
            .onEnded { _ in
                isDragging = false
                if dragOffset > totalExpandedHeight * 0.1 {
                    // Pulled down > 10%: roller blind release → collapse
                    completeCollapseFromDrag()
                } else if dragOffset < -totalExpandedHeight * 0.5 {
                    // Pushed up > 50%: collapse
                    completeCollapseFromDrag()
                } else {
                    snapBack()
                }
            }
    }

    // MARK: - Animations

    private func expandAnimation() {
        playLottie = true
        // Full size immediately, hidden above screen, invisible
        currentHeight = totalExpandedHeight
        yOffset = -totalExpandedHeight - 20
        contentOpacity = 0
        // Spring drop down with overshoot + fade in
        withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
            yOffset = 0
            contentOpacity = 1
        }
    }

    private func collapseAnimation() {
        playLottie = false
        // Phase 1: slight upward nudge
        withAnimation(.spring(response: 0.12, dampingFraction: 0.3)) {
            yOffset = -15
            contentOpacity = 0.7
        } completion: {
            // Phase 2: accelerate off screen
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                yOffset = -totalExpandedHeight - 20
                contentOpacity = 0
            } completion: {
                currentHeight = 0
                yOffset = 0
            }
        }
    }

    private func completeCollapseFromDrag() {
        isAnimatingCollapse = true
        // Absorb drag offset into currentHeight
        let visibleH = max(0, currentHeight + dragOffset)
        currentHeight = visibleH
        dragOffset = 0
        // Phase 1: slight upward nudge
        withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
            yOffset = -12
        } completion: {
            // Phase 2: accelerate off screen
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                yOffset = -visibleH - 20
                contentOpacity = 0
            } completion: {
                isAnimatingCollapse = false
                currentHeight = 0
                yOffset = 0
                timerManager.collapseFromDrag()
            }
        }
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            dragOffset = 0
            yOffset = 0
            contentOpacity = 1
        }
    }

    // MARK: - Panel Frame

    private func updatePanelFrame() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.frame
        let w = visibleWidth
        let h = visibleHeight
        let ox = sf.midX - w / 2
        let oy = sf.maxY - h - yOffset  // screen coords: account for slide offset
        panelProxy.popupFrame = NSRect(x: ox, y: oy, width: w, height: h)
    }
}

