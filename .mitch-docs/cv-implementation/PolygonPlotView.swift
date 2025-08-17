import UIKit

final class PolygonPlotView: UIView {
    private var modelPolygons: [[CGPoint]] = []
    private var modelFillColors: [UIColor] = []

    private static let jsonColorsByClassId: [Int: UIColor] = {
        var mapping: [Int: UIColor] = [:]
        guard let path = Bundle.main.path(forResource: "tangram_shapes_2d", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let root = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return mapping
        }
        let idToName: [Int: String] = [
            0: "tangram_parallelogram",
            1: "tangram_square",
            2: "tangram_triangle_lrg",
            3: "tangram_triangle_lrg2",
            4: "tangram_triangle_med",
            5: "tangram_triangle_sml",
            6: "tangram_triangle_sml2"
        ]
        for (cid, name) in idToName {
            if let obj = root[name] as? [String: Any],
               let arr = obj["color"] as? [Any], arr.count >= 3,
               let rN = arr[0] as? NSNumber, let gN = arr[1] as? NSNumber, let bN = arr[2] as? NSNumber {
                let r = CGFloat(truncating: rN) / 255.0
                let g = CGFloat(truncating: gN) / 255.0
                let b = CGFloat(truncating: bN) / 255.0
                mapping[cid] = UIColor(red: r, green: g, blue: b, alpha: 0.35)
            }
        }
        return mapping
    }()

    func update(modelPlanePolygons planeModel: [NSNumber: [NSNumber]], modelColorsRGB: [NSNumber: [NSNumber]]? = nil) {
        modelPolygons.removeAll()
        modelFillColors.removeAll()
        // Keep deterministic order by class id sorting
        for entry in planeModel.sorted(by: { $0.key.intValue < $1.key.intValue }) {
            let arr = entry.value
            var pts: [CGPoint] = []
            var j = 0
            while j + 1 < arr.count {
                let x = CGFloat(truncating: arr[j])
                let y = CGFloat(truncating: arr[j+1])
                pts.append(CGPoint(x: x, y: y))
                j += 2
            }
            if pts.count >= 3 {
                modelPolygons.append(pts)
                // Prefer JSON color mapping; fall back to wrapper-provided modelColorsRGB
                if let col = PolygonPlotView.jsonColorsByClassId[entry.key.intValue] {
                    modelFillColors.append(col)
                } else if let rgb = modelColorsRGB?[entry.key], rgb.count >= 3 {
                    let r = CGFloat(truncating: rgb[0]) / 255.0
                    let g = CGFloat(truncating: rgb[1]) / 255.0
                    let b = CGFloat(truncating: rgb[2]) / 255.0
                    modelFillColors.append(UIColor(red: r, green: g, blue: b, alpha: 0.35))
                } else {
                    modelFillColors.append(UIColor.white.withAlphaComponent(0.35))
                }
            }
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard !modelPolygons.isEmpty else { return }
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.saveGState()
        defer { ctx?.restoreGState() }

        // Fit plane coordinates to this view keeping aspect ratio (model polygons only)
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for poly in modelPolygons {
            for p in poly {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
        }
        let pad: CGFloat = 8
        let srcW = max(1, maxX - minX)
        let srcH = max(1, maxY - minY)
        let scale = min((bounds.width - 2*pad)/srcW, (bounds.height - 2*pad)/srcH)
        let offset = CGPoint(x: (bounds.width - scale*srcW)/2 - scale*minX,
                             y: (bounds.height - scale*srcH)/2 - scale*minY)

        // Removed rendering of detected polygons

        // Draw model polygons: fill with .mtl color, stroke white
        for (idx, poly) in modelPolygons.enumerated() {
            guard poly.count >= 3 else { continue }
            let path = UIBezierPath()
            let p0 = CGPoint(x: poly[0].x*scale + offset.x, y: poly[0].y*scale + offset.y)
            path.move(to: p0)
            for k in 1..<poly.count {
                let pk = CGPoint(x: poly[k].x*scale + offset.x, y: poly[k].y*scale + offset.y)
                path.addLine(to: pk)
            }
            path.close()
            // Fill
            let fill = (idx < modelFillColors.count) ? modelFillColors[idx] : UIColor.white.withAlphaComponent(0.35)
            fill.setFill()
            path.fill()
            // Stroke
            UIColor.white.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
    }
}

