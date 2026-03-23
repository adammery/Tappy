import SwiftUI

struct MouseHeatmapView: View {
    let leftClicks: Int
    let rightClicks: Int
    let middleClicks: Int

    private var maxCount: Int {
        max(leftClicks, rightClicks, middleClicks, 1)
    }

    private func intensity(for count: Int) -> Double {
        let raw = Double(count) / Double(maxCount)
        return count == 0 ? 0 : raw
    }

    private func heatColor(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color.primary.opacity(0.05)
        }
        return Color.orange.opacity(0.15 + intensity * 0.7)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Mouse outline
            ZStack {
                mouseShape
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)

                // Left button
                MouseButton(side: .left)
                    .fill(heatColor(intensity(for: leftClicks)))
                    .zIndex(2)
                MouseButton(side: .left)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.55)
                    .zIndex(2)

                // Right button
                MouseButton(side: .right)
                    .fill(heatColor(intensity(for: rightClicks)))
                    .zIndex(2)
                MouseButton(side: .right)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.55)
                    .zIndex(2)

                // Middle wheel
                RoundedRectangle(cornerRadius: 0)
                    .fill(heatColor(intensity(for: middleClicks)))
                    .frame(width: 5, height: 32)
                    .offset(y: -16)
                    .zIndex(1)
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.35)
                    .frame(width: 5, height: 32)
                    .offset(y: -16)
                    .zIndex(1)
            }
            .frame(width: 60, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                clickRow("Left", count: leftClicks)
                clickRow("Right", count: rightClicks)
                clickRow("Middle", count: middleClicks)
            }
            .padding(.leading, 12)
        }
    }

    private func clickRow(_ label: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(heatColor(intensity(for: count)))
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(count.compact)
                .font(.caption2)
                .fontDesign(.monospaced)
        }
    }

    private var mouseShape: some Shape {
        AsymmetricMouseOutlineShape(topCornerRadius: 26, bottomCornerRadius: 20)
    }

    struct AsymmetricMouseOutlineShape: Shape {
        let topCornerRadius: CGFloat
        let bottomCornerRadius: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()

            let x0 = rect.minX
            let x1 = rect.maxX
            let y0 = rect.minY
            let y1 = rect.maxY

            let maxPossible = min(rect.width, rect.height) / 2
            let rTop = min(topCornerRadius, maxPossible)
            let rBottom = min(bottomCornerRadius, maxPossible)

            path.move(to: CGPoint(x: x0 + rTop, y: y0))

            path.addLine(to: CGPoint(x: x1 - rTop, y: y0))
            path.addQuadCurve(
                to: CGPoint(x: x1, y: y0 + rTop),
                control: CGPoint(x: x1, y: y0)
            )

            path.addLine(to: CGPoint(x: x1, y: y1 - rBottom))
            path.addQuadCurve(
                to: CGPoint(x: x1 - rBottom, y: y1),
                control: CGPoint(x: x1, y: y1)
            )
            path.addLine(to: CGPoint(x: x0 + rBottom, y: y1))
            path.addQuadCurve(
                to: CGPoint(x: x0, y: y1 - rBottom),
                control: CGPoint(x: x0, y: y1)
            )
            path.addLine(to: CGPoint(x: x0, y: y0 + rTop))
            path.addQuadCurve(
                to: CGPoint(x: x0 + rTop, y: y0),
                control: CGPoint(x: x0, y: y0)
            )

            path.closeSubpath()
            return path
        }
    }

    enum ButtonSide {
        case left, right
    }

    struct MouseButton: Shape {
        let side: ButtonSide

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let mid = rect.midX
            let top = rect.minY + 4
            let bottom = rect.minY + rect.height * 0.5
            let cornerRadius: CGFloat = 22
            // Want ~1px gap on the left of the middle, and ~1px more on the right.
            // This view is asymmetric by tuning insets independently.
            let centerGapLeft: CGFloat = 7
            let centerGapRight: CGFloat = 8
            let centerInsetLeft = centerGapLeft / 2
            let centerInsetRight = centerGapRight / 2

            switch side {
            case .left:
                path.move(to: CGPoint(x: mid - centerInsetLeft, y: top + cornerRadius))
                path.addLine(to: CGPoint(x: mid - centerInsetLeft, y: bottom))
                path.addLine(to: CGPoint(x: rect.minX + 4, y: bottom))
                path.addLine(to: CGPoint(x: rect.minX + 4, y: top + cornerRadius))
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX + 4 + cornerRadius, y: top),
                    control: CGPoint(x: rect.minX + 4, y: top)
                )
                path.addLine(to: CGPoint(x: mid - centerInsetLeft, y: top))
                path.closeSubpath()
            case .right:
                path.move(to: CGPoint(x: mid + centerInsetRight, y: top + cornerRadius))
                path.addLine(to: CGPoint(x: mid + centerInsetRight, y: bottom))
                path.addLine(to: CGPoint(x: rect.maxX - 4, y: bottom))
                path.addLine(to: CGPoint(x: rect.maxX - 4, y: top + cornerRadius))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - 4 - cornerRadius, y: top),
                    control: CGPoint(x: rect.maxX - 4, y: top)
                )
                path.addLine(to: CGPoint(x: mid + centerInsetRight, y: top))
                path.closeSubpath()
            }
            return path
        }
    }
}
