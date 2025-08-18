import CoreGraphics

extension CGPath {
    func extractPolygonPoints() -> [CGPoint] {
        var points: [CGPoint] = []
        self.applyWithBlock { elementPtr in
            let e = elementPtr.pointee
            switch e.type {
            case .moveToPoint:
                points.append(e.points[0])
            case .addLineToPoint:
                points.append(e.points[0])
            case .closeSubpath:
                break
            case .addQuadCurveToPoint:
                points.append(e.points[1])
            case .addCurveToPoint:
                points.append(e.points[2])
            @unknown default:
                break
            }
        }
        return points
    }
}


