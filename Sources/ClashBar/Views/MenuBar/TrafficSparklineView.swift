import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

struct TrafficSparklineView: View {
    let upValues: [Int64]
    let downValues: [Int64]

    var body: some View {
        GeometryReader { geo in
            let maxY = max(1.0, Double(max(self.downValues.max() ?? 0, self.upValues.max() ?? 0)))
            let axisY = floor(geo.size.height * 0.5)
            let upperSpan = max(1, axisY - 2)
            let lowerSpan = max(1, geo.size.height - axisY - 2)
            let maxPoints = 60
            let upContext = SparklinePathContext(
                width: geo.size.width,
                axisY: axisY,
                span: upperSpan,
                maxY: maxY,
                direction: .up,
                maxPoints: maxPoints)
            let downContext = SparklinePathContext(
                width: geo.size.width,
                axisY: axisY,
                span: lowerSpan,
                maxY: maxY,
                direction: .down,
                maxPoints: maxPoints)

            ZStack {
                self.axisPath(width: geo.size.width, axisY: axisY)
                    .stroke(
                        Color(nsColor: .separatorColor).opacity(0.55),
                        style: StrokeStyle(lineWidth: T.stroke, lineCap: .round))

                self.lineAreaPath(for: self.upValues, context: upContext)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .controlAccentColor).opacity(0.30),
                                Color(nsColor: .controlAccentColor).opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom))

                self.lineAreaPath(for: self.downValues, context: downContext)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .systemGreen).opacity(0.32),
                                Color(nsColor: .systemGreen).opacity(0.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom))

                self.linePath(for: self.upValues, context: upContext)
                    .stroke(
                        Color(nsColor: .controlAccentColor).opacity(0.9),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))

                self.linePath(for: self.downValues, context: downContext)
                    .stroke(
                        Color(nsColor: .systemGreen).opacity(0.9),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func linePath(for values: [Int64], context: SparklinePathContext) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }

        for index in 0..<values.count {
            let p = self.point(at: index, in: values, context: context)
            if index == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }
        return path
    }

    private func lineAreaPath(for values: [Int64], context: SparklinePathContext) -> Path {
        var path = self.linePath(for: values, context: context)
        guard !values.isEmpty else { return path }

        let firstPointX = self.point(at: 0, in: values, context: context).x
        let lastPointX = self.point(at: values.count - 1, in: values, context: context).x
        
        path.addLine(to: CGPoint(x: lastPointX, y: context.axisY))
        path.addLine(to: CGPoint(x: firstPointX, y: context.axisY))
        path.closeSubpath()
        return path
    }

    private func point(at index: Int, in values: [Int64], context: SparklinePathContext) -> CGPoint {
        let clampedIndex = min(max(index, 0), values.count - 1)
        let offsetFromRight = values.count - 1 - clampedIndex
        let x = context.width - (CGFloat(offsetFromRight) / CGFloat(max(context.maxPoints - 1, 1)) * context.width)
        let y = self.yPosition(
            values[clampedIndex],
            axisY: context.axisY,
            span: context.span,
            maxY: context.maxY,
            direction: context.direction)
        return CGPoint(x: x, y: y)
    }

    private func axisPath(width: CGFloat, axisY: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: axisY))
        path.addLine(to: CGPoint(x: width, y: axisY))
        return path
    }

    private func yPosition(
        _ value: Int64,
        axisY: CGFloat,
        span: CGFloat,
        maxY: Double,
        direction: LineDirection) -> CGFloat
    {
        let clamped = max(0.0, min(Double(value), maxY))
        let ratio = CGFloat(clamped / maxY)

        switch direction {
        case .up:
            return axisY - ratio * span
        case .down:
            return axisY + ratio * span
        }
    }

    private struct SparklinePathContext {
        let width: CGFloat
        let axisY: CGFloat
        let span: CGFloat
        let maxY: Double
        let direction: LineDirection
        let maxPoints: Int
    }

    private enum LineDirection {
        case up
        case down
    }
}
