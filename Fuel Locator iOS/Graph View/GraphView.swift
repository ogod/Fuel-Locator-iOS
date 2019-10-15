//
//  GraphView.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 30/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit

class GraphView: UIView {

    private var bands = Array<GraphBand?>(repeating: nil, count: 10)
    private var sevenDayAverage: GraphSevenDayAverage! = nil
    var xStart: CGFloat = GraphBand.xValue(Date()) - 365
    var xEnd: CGFloat = GraphBand.xValue(Date())
    var yHeight: CGFloat = 100
    let minHeight: CGFloat = 283.0
    let textMargin: CGFloat = 8.0
    let textShadowBlur: CGFloat = 5.0
    let textMajorFontSize: CGFloat = 30.0
    let textMinorFontSize: CGFloat = 18.0
    var ready = false {
        didSet {
            if ready == true {
                setNeedsDisplay()
            }
        }
    }
    private var _xScale: CGFloat = 6.0
    var xScale: CGFloat {
        set {
            _xScale = newValue.clamped(to: 1...40)
        }
        get {
            return _xScale
        }
    }
    var height: CGFloat { return max(yHeight, 812) }
    var width: CGFloat { return (xEnd - xStart + 2) * xScale }
    var graphSize: CGSize?

    /// Defines the stride of the x axis based on current parameters
    var xStride: StrideTo<CGFloat> {
        let strideBy: CGFloat
        switch xScale {
        case -CGFloat.greatestFiniteMagnitude ..< 3:
            strideBy = 14
        case 3 ..< 15:
            strideBy = 7
        case 15 ... CGFloat.greatestFiniteMagnitude:
            strideBy = 1
        default:
            strideBy = 7
        }
        return stride(from: floor((xStart - 1) / 7 + 0.5) * 7, to: xEnd + 1, by: strideBy)
    }

    /// Defines the minor stride of the x axis
    var xMinorStride: StrideTo<CGFloat> {
        return stride(from: xStart, to: xEnd + 1, by: 1)
    }

    private var dateBandSequence: MajorDateSequence {
        var cd = DateComponents(calendar: XAxisView.cal,
                                timeZone: XAxisView.timeZone)
        switch xScale {
        case -CGFloat.greatestFiniteMagnitude ..< 3:
            cd.month = 1
        case 3 ..< 15:
            cd.day = 1
        case 15 ... CGFloat.greatestFiniteMagnitude:
            cd.weekday = 2
        default:
            cd.day = 1
        }
        return MajorDateSequence(first: GraphBand.date(xStart),
                                 last: GraphBand.date(xEnd),
                                 matching: cd)
    }

    override class var layerClass: AnyClass {
        get {
            return CATiledLayer.self
        }
    }

    var tiledLayer: CATiledLayer {
        return self.layer as! CATiledLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        tiledLayer.levelsOfDetail = 4
        tiledLayer.tileSize = CGSize(width: 1024, height: 1024)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        tiledLayer.levelsOfDetail = 4
        tiledLayer.tileSize = CGSize(width: 1024, height: 1024)
    }

    static let formatters: [String: DateFormatter] = [
        "year" : {
            let df = DateFormatter()
            df.dateFormat = """
                            YYYY
                            """
            return df
        }(),
        "month" : {
            let df = DateFormatter()
            df.dateFormat = """
                            MMM
                            YYYY
                            """
            return df
        }(),
        "month long" : {
            let df = DateFormatter()
            df.dateFormat = """
                            MMMM
                            YYYY
                            """
            return df
        }(),
        "week" : {
            let df = DateFormatter()
            df.dateFormat = """
                            'Wk' W
                            MMM
                            YYYY
                            """
            return df
        }(),
        "week long" : {
            let df = DateFormatter()
            df.dateFormat = """
                            'Week' W
                            MMMM
                            YYYY
                            """
            return df
        }(),
    ]

    private var formatter: DateFormatter {
        switch xScale {
        case -CGFloat.greatestFiniteMagnitude ..< 3:
            return GraphView.formatters["year"]!
        case 3 ..< 15:
            return GraphView.formatters["month"]!
        case 15 ... CGFloat.greatestFiniteMagnitude:
            return GraphView.formatters["week"]!
        default:
            return GraphView.formatters["month"]!
        }
    }

    private var longFormatter: DateFormatter {
        switch xScale {
        case -CGFloat.greatestFiniteMagnitude ..< 3:
            return GraphView.formatters["year"]!
        case 3 ..< 15:
            return GraphView.formatters["month long"]!
        case 15 ... CGFloat.greatestFiniteMagnitude:
            return GraphView.formatters["week long"]!
        default:
            return GraphView.formatters["month long"]!
        }
    }

    /// Defines the stride of the y axis
    var yStride: StrideTo<CGFloat> {
        let strideBy: CGFloat
        switch yHeight * 200 / (graphSize?.height ?? minHeight) {
        case 200..<CGFloat.greatestFiniteMagnitude:
            strideBy = 50
        case 80..<200:
            strideBy = 20
        case 40..<80:
            strideBy = 10
        case 20..<40:
            strideBy = 5
        case 8..<20:
            strideBy = 2
        case 4..<8:
            strideBy = 1
        case 2..<4:
            strideBy = 0.5
        case -CGFloat.greatestFiniteMagnitude..<2:
            strideBy = 0.2
        default:
            strideBy = 10
        }
        return stride(from: 0, to: yHeight - strideBy / 5.0, by: strideBy)
    }

    /// Defines the minor stride of the y axis
    var yMinorStride: StrideTo<CGFloat> {
        let strideBy: CGFloat
        switch yHeight * 200 / (graphSize?.height ?? minHeight) {
        case 200..<CGFloat.greatestFiniteMagnitude:
            strideBy = 10
        case 80..<200:
            strideBy = 10
        case 40..<80:
            strideBy = 2
        case 20..<40:
            strideBy = 1
        case 8..<20:
            strideBy = 1
        case 4..<8:
            strideBy = 0.2
        case 2..<4:
            strideBy = 0.1
        case -CGFloat.greatestFiniteMagnitude..<2:
            strideBy = 0.1
        default:
            strideBy = 2
        }
        return stride(from: 0, to: yHeight - strideBy / 5.0, by: strideBy)
    }

    /// Defines the background gradient stride of the y axis
    var yGradientStride: StrideTo<CGFloat> {
        let strideBy: CGFloat
        switch yHeight {
        case 10000..<CGFloat.greatestFiniteMagnitude:
            strideBy = 10000
        case 1000..<10000:
            strideBy = 1000
        case 100..<1000:
            strideBy = 100
        case 10..<100:
            strideBy = 10
        case 0..<10:
            strideBy = 1
        default:
            strideBy = 100
        }
        return stride(from: 0, to: yHeight + strideBy, by: strideBy)
    }

    func yStrideRank(value: CGFloat) -> InterceptRank {
        if value.truncatingRemainder(dividingBy: 100) == 0 {
            return .critical
        }
        switch yHeight * 200 / (graphSize?.height ?? minHeight) {
        case 200..<CGFloat.greatestFiniteMagnitude:
            return (value/10).truncatingRemainder(dividingBy: 5) == 0 ? .major : .minor
        case 80..<200:
            return (value/10).truncatingRemainder(dividingBy: 2) == 0 ? .major : .minor
        case 40..<80:
            return (value/2).truncatingRemainder(dividingBy: 5) == 0 ? .major : .minor
        case 20..<40:
            return (value/1).truncatingRemainder(dividingBy: 5) == 0 ? .major : .minor
        case 8..<20:
            return (value/1).truncatingRemainder(dividingBy: 2) == 0 ? .major : .minor
        case 4..<8:
            return (value/0.2).truncatingRemainder(dividingBy: 5) == 0 ? .major : .minor
        case 2..<4:
            return (value/0.1).truncatingRemainder(dividingBy: 5) == 0 ? .major : .minor
        case -CGFloat.greatestFiniteMagnitude..<2:
            return (value/0.1).truncatingRemainder(dividingBy: 2) == 0 ? .major : .minor
        default:
            return (value/2).truncatingRemainder(dividingBy: 5) == 0 ? .major : .minor
        }
    }

    enum InterceptRank {
        case minor
        case major
        case critical
    }

    func generateBands(fromStatistics stats: Set<Statistics>) {
        let s = stats.filter({$0.minimum != nil})
        bands[0] = GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per10!.int16Value, low: $0.minimum!.int16Value, date: $0.date)})))
        bands[1] = GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per20!.int16Value, low: $0.per10!.int16Value, date: $0.date)})))
        bands[2] = GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per30!.int16Value, low: $0.per20!.int16Value, date: $0.date)})))
        bands[3] = GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per40!.int16Value, low: $0.per30!.int16Value, date: $0.date)})))
        bands[4] = GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per50!.int16Value, low: $0.per40!.int16Value, date: $0.date)})))
        bands[5] = GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per60!.int16Value, low: $0.per50!.int16Value, date: $0.date)})))
        bands[6] = GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per70!.int16Value, low: $0.per60!.int16Value, date: $0.date)})))
        bands[7] = GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per80!.int16Value, low: $0.per70!.int16Value, date: $0.date)})))
        bands[8] = GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per90!.int16Value, low: $0.per80!.int16Value, date: $0.date)})))
        bands[9] = GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.maximum!.int16Value, low: $0.per90!.int16Value, date: $0.date)})))
        sevenDayAverage = GraphSevenDayAverage(values: AnySequence<PricePointValue>(s.filter({$0.mean != nil}).map({(value: $0.mean!.int16Value, date: $0.date)})))
        xStart = bands.map({$0?.xStart ?? 0}).min() ?? 1
        xEnd = bands.map({$0?.xEnd ?? 0}).max() ?? 1
        yHeight = floor((bands.map({$0?.yHeight ?? 0}).max() ?? 0.0) / 10.0 + 1.0) * 10.0
    }

    static let colours = [
        UIColor(named: "per10"),
        UIColor(named: "per20"),
        UIColor(named: "per30"),
        UIColor(named: "per40"),
        UIColor(named: "per50"),
        UIColor(named: "per60"),
        UIColor(named: "per70"),
        UIColor(named: "per80"),
        UIColor(named: "per90"),
        UIColor(named: "per100")
        ]

    private struct MajorDateSequence: Sequence, IteratorProtocol {
        let first: Date
        let last: Date
        let matching: DateComponents
        var current: Date? = nil
        var completed = false

        let monthComp = DateComponents(calendar: XAxisView.cal,
                                       timeZone: XAxisView.timeZone,
                                       day: 1)

        init(first: Date, last: Date, matching: DateComponents) {
            self.first = first
            self.last = last
            self.matching = matching
        }

        mutating func next() -> Date? {
            guard !completed else {
                return nil
            }
            if let c = current {
                var c1 = GraphBand.calendar.nextDate(after: c,
                                                     matching: matching,
                                                     matchingPolicy: .nextTime,
                                                     repeatedTimePolicy: .first,
                                                     direction: .forward)!
                if matching.weekday != nil {
                    let c2 = GraphBand.calendar.nextDate(after: c,
                                                         matching: monthComp,
                                                         matchingPolicy: .nextTime,
                                                         repeatedTimePolicy: .first,
                                                         direction: .forward)!
                    if c2 < c1 {
                        c1 = c2
                    }
                }
                current = c1
            } else {
                current = first
            }
            if current! >= last {
                current = last
                completed = true
            }
            return current
        }
    }

    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        guard graphSize != nil else {
            return
        }

        let xScale: CGFloat = graphSize!.width / (xEnd - xStart + 2)
        let yScale: CGFloat = graphSize!.height / max(yHeight, 1)
        let transform = CGAffineTransform(scaleX: xScale, y: -yScale).translatedBy(x: -xStart + 1, y: -yHeight)
        let startDate = XAxisView.cal.date(from: DateComponents(calendar: XAxisView.cal,
                                                                timeZone: XAxisView.timeZone,
                                                                year: 2001,
                                                                month: 1,
                                                                day: 1))!

        var gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor.blue.withAlphaComponent(0.025).cgColor,
                                           UIColor.white.withAlphaComponent(0.025).cgColor] as CFArray,
                                  locations: [0.0 as CGFloat, 1.0 as CGFloat])!
        if let context = UIGraphicsGetCurrentContext() {
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            let font = UIFont.boldSystemFont(ofSize: textMajorFontSize)
            let font3 = UIFont.boldSystemFont(ofSize: textMinorFontSize)
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.5)
            shadow.shadowBlurRadius = textShadowBlur
            let attr: [NSAttributedString.Key : Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.75),
                                                        .font: font,
                                                        .paragraphStyle: para,
                                                        .shadow: shadow]
            let attr3: [NSAttributedString.Key : Any] = [.foregroundColor: UIColor.white.withAlphaComponent(0.75),
                                                        .font: font3,
                                                        .paragraphStyle: para,
                                                        .shadow: shadow]
            var date: Date! = nil
            for nextDate in dateBandSequence {
                defer { date = nextDate }
                guard date != nil else {
                    continue
                }
                let str = NSAttributedString(string: longFormatter.string(from: date),
                                             attributes: attr)
                let strSize = str.size()
                let str2 = NSAttributedString(string: formatter.string(from: date),
                                              attributes: attr)
                let strSize2 = str2.size()
                let str3 = NSAttributedString(string: formatter.string(from: date),
                                              attributes: attr3)
                let strSize3 = str3.size()
                var y:CGFloat! = nil
                for nextY in yGradientStride {
                    defer { y = nextY }
                    guard y != nil else {
                        continue
                    }
                    context.saveGState()
                    defer { context.restoreGState() }
                    let origin = CGPoint(x: GraphBand.xValue(date), y: nextY).applying(transform)
                    let rectEnd = CGPoint(x: GraphBand.xValue(nextDate), y: y).applying(transform)
                    let gradientEnd1 = CGPoint(x: GraphBand.xValue(nextDate), y: nextY).applying(transform)
                    let gradientEnd2 = CGPoint(x: GraphBand.xValue(date), y: y).applying(transform)
                    let size = CGSize(width: rectEnd.x - origin.x, height: rectEnd.y - origin.y)
                    let rect = CGRect(origin: origin, size: size)
                    let scRect = rect.intersection(CGRect(origin: CGPoint.zero, size: graphSize!))
                    UIRectClip(scRect)
                    context.drawLinearGradient(gradient, start: origin, end: gradientEnd1, options: [.drawsAfterEndLocation])
                    context.drawLinearGradient(gradient, start: origin, end: gradientEnd2, options: [.drawsAfterEndLocation])
                    let drawRect = scRect.insetBy(dx: (scRect.width - strSize.width) / 2, dy: (scRect.height - strSize.height) / 2)
                    let drawRect2 = scRect.insetBy(dx: (scRect.width - strSize2.width) / 2, dy: (scRect.height - strSize2.height) / 2)
                    let drawRect3 = scRect.insetBy(dx: (scRect.width - strSize3.width) / 2, dy: (scRect.height - strSize3.height) / 2)
                    if drawRect.minX >= scRect.minX + textMargin && drawRect.minY >= scRect.minY + textMargin {
                        str.draw(in: drawRect)
                    } else if drawRect2.minX >= scRect.minX + textMargin && drawRect2.minY >= scRect.minY + textMargin {
                        str2.draw(in: drawRect2)
                    } else if drawRect3.minX >= scRect.minX + textMargin && drawRect3.minY >= scRect.minY + textMargin {
                        str3.draw(in: drawRect3)
                    }
                }
            }
        }

        for y in yMinorStride {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: xStart, y: y))
            path.addLine(to: CGPoint(x: xEnd, y: y))
            path.apply(transform)
            switch yStrideRank(value: y) {
            case .critical:
                UIColor.gray.withAlphaComponent(0.75).setStroke()
            case .major:
                UIColor.lightGray.withAlphaComponent(0.5).setStroke()
            case .minor:
                UIColor.lightGray.withAlphaComponent(0.25).setStroke()
            }
            path.lineWidth = 0.5
            path.stroke()
        }

        for x in xMinorStride {
            guard xStart ... xEnd ~= x else {
                continue
            }
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: yHeight))
            path.apply(transform)
            path.lineWidth = 0.5
            let date = XAxisView.cal.date(byAdding: .day, value: Int(x), to: startDate)!
            let dayOfMonth = XAxisView.cal.component(.day, from: date)
            if dayOfMonth == 1 {
                UIColor.gray.withAlphaComponent(0.75).setStroke()
                path.setLineDash([CGFloat(4), CGFloat(4)], count: 2, phase: 0)
            } else if Int(x) % 7 == 0 {
                UIColor.gray.withAlphaComponent(0.5).setStroke()
            } else {
                UIColor.lightGray.withAlphaComponent(0.25).setStroke()
            }
            path.stroke()
        }

        guard ready else {
            return
        }

        for i in 0..<bands.count {
            if let band = bands[i] {
                let colour = GraphView.colours[i]!
                colour.setFill()

                let context = UIGraphicsGetCurrentContext()!
                let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.genericRGBLinear),
                                          colors: [UIColor.clear.cgColor, colour.cgColor] as CFArray,
                                          locations: nil)!

                for a in band.fadeInAreas {
                    let a1 = UIBezierPath(cgPath: a.cgPath)
                    a1.apply(transform)
                    context.saveGState()
                    context.setAlpha(0.5)
                    a1.addClip()
                    let r = a1.bounds
                    context.drawLinearGradient(gradient,
                                               start: CGPoint(x: r.minX, y: r.midY),
                                               end: CGPoint(x: r.maxX, y: r.midY),
                                               options: [])
                    context.restoreGState()
                }
                for a in band.fillAreas {
                    let a1 = UIBezierPath(cgPath: a.cgPath)
                    a1.apply(transform)
                    a1.fill(with: .normal, alpha: 0.5)
                }
                for a in band.fadeOutAreas {
                    let a1 = UIBezierPath(cgPath: a.cgPath)
                    a1.apply(transform)
                    context.saveGState()
                    context.setAlpha(0.5)
                    a1.addClip()
                    let r = a1.bounds
                    context.drawLinearGradient(gradient,
                                               start: CGPoint(x: r.maxX, y: r.midY),
                                               end: CGPoint(x: r.minX, y: r.midY),
                                               options: [])
                    context.restoreGState()
                }
                colour.setStroke()
                for a in band.fadeInLines {
                    let a1 = UIBezierPath(cgPath: a.cgPath)
                    a1.apply(transform)
                    let r = a1.bounds
                    context.saveGState()
                    context.addPath(a1.cgPath)
                    context.setLineWidth(1)
                    context.replacePathWithStrokedPath()
                    context.clip()
                    context.drawLinearGradient(gradient,
                                               start: CGPoint(x: r.minX, y: r.midY),
                                               end: CGPoint(x: r.maxX, y: r.midY),
                                               options: [])
                    context.restoreGState()
                }
                for a in band.lines {
                    let a1 = UIBezierPath(cgPath: a.cgPath)
                    a1.apply(transform)
                    a1.stroke(with: .normal, alpha: 1)
                }
                for a in band.fadeOutLines {
                    let a1 = UIBezierPath(cgPath: a.cgPath)
                    a1.apply(transform)
                    let r = a1.bounds
                    context.saveGState()
                    context.addPath(a1.cgPath)
                    context.setLineWidth(1)
                    context.replacePathWithStrokedPath()
                    context.clip()
                    context.drawLinearGradient(gradient,
                                               start: CGPoint(x: r.maxX, y: r.midY),
                                               end: CGPoint(x: r.minX, y: r.midY),
                                               options: [])
                    context.restoreGState()
                }
            }
        }

        if let band = sevenDayAverage {
            let colour = UIColor.purple

            let context = UIGraphicsGetCurrentContext()!
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.genericRGBLinear),
                                      colors: [UIColor.clear.cgColor, colour.cgColor] as CFArray,
                                      locations: nil)!

            colour.setStroke()
            for a in band.fadeInLines {
                let a1 = UIBezierPath(cgPath: a.cgPath)
                a1.apply(transform)
                let r = a1.bounds
                context.saveGState()
                context.addPath(a1.cgPath)
                context.setLineWidth(0.5)
                context.replacePathWithStrokedPath()
                context.clip()
                context.drawLinearGradient(gradient,
                                           start: CGPoint(x: r.minX, y: r.midY),
                                           end: CGPoint(x: r.maxX, y: r.midY),
                                           options: [])
                context.restoreGState()
            }
            for a in band.lines {
                let a1 = UIBezierPath(cgPath: a.cgPath)
                a1.apply(transform)
                a1.stroke(with: .normal, alpha: 1)
            }
            for a in band.fadeOutLines {
                let a1 = UIBezierPath(cgPath: a.cgPath)
                a1.apply(transform)
                let r = a1.bounds
                context.saveGState()
                context.addPath(a1.cgPath)
                context.setLineWidth(0.5)
                context.replacePathWithStrokedPath()
                context.clip()
                context.drawLinearGradient(gradient,
                                           start: CGPoint(x: r.maxX, y: r.midY),
                                           end: CGPoint(x: r.minX, y: r.midY),
                                           options: [])
                context.restoreGState()
            }
        }
    }

}
