import SwiftUI

/// 自定义 Notch 反圆角矩形
/// 顶部两侧有反圆角（flareRadius），贴合 MacBook 刘海轮廓
/// 底部两侧为正常圆角（cornerRadius）
struct NotchShape: Shape {
    var cornerRadius: CGFloat
    var flareRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, flareRadius) }
        set {
            cornerRadius = newValue.first
            flareRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        let maxCornerSpace = min(w / 2, h / 2)
        let totalRadii = flareRadius + cornerRadius
        let scale = totalRadii > 0 ? min(1.0, maxCornerSpace / totalRadii) : 1.0

        let currentFlare = flareRadius * scale
        let currentCorner = cornerRadius * scale

        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(
            to: CGPoint(x: currentFlare, y: currentFlare),
            control1: CGPoint(x: currentFlare * 0.5, y: 0),
            control2: CGPoint(x: currentFlare, y: currentFlare * 0.5)
        )

        path.addLine(to: CGPoint(x: currentFlare, y: h - currentCorner))

        path.addCurve(
            to: CGPoint(x: currentFlare + currentCorner, y: h),
            control1: CGPoint(x: currentFlare, y: h - currentCorner * 0.5),
            control2: CGPoint(x: currentFlare + currentCorner * 0.5, y: h)
        )

        path.addLine(to: CGPoint(x: w - currentFlare - currentCorner, y: h))

        path.addCurve(
            to: CGPoint(x: w - currentFlare, y: h - currentCorner),
            control1: CGPoint(x: w - currentFlare - currentCorner * 0.5, y: h),
            control2: CGPoint(x: w - currentFlare, y: h - currentCorner * 0.5)
        )

        path.addLine(to: CGPoint(x: w - currentFlare, y: currentFlare))

        path.addCurve(
            to: CGPoint(x: w, y: 0),
            control1: CGPoint(x: w - currentFlare, y: currentFlare * 0.5),
            control2: CGPoint(x: w - currentFlare * 0.5, y: 0)
        )

        path.closeSubpath()
        return path
    }
}
