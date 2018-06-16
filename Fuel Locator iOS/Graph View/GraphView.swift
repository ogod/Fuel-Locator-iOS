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
    var xStart: CGFloat = 0
    var xEnd: CGFloat = 0
    var yHeight: CGFloat = 0
    let minHeight: CGFloat = 283.0
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
            _xScale = max(min(newValue, 40), 1)
        }
        get {
            return _xScale
        }
    }
    var height: CGFloat { return max(yHeight, 812) }
    var width: CGFloat { return (xEnd - xStart + 2) * xScale }

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

    var yStride: StrideTo<CGFloat> {
        let strideBy: CGFloat
        switch yHeight * 200 / bounds.height {
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
        sevenDayAverage = GraphSevenDayAverage(values: AnySequence<PricePointValue>(s.map({(value: $0.mean!.int16Value, date: $0.date)})))
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

    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        guard ready else {
            return
        }

        print("Draw Graph, \(rect), \(bounds)")

        let xScale: CGFloat = bounds.width / (xEnd - xStart + 2)
        let yScale: CGFloat = bounds.height / max(yHeight, 1)


        let transform = CGAffineTransform(scaleX: xScale, y: -yScale).translatedBy(x: -xStart + 1, y: -yHeight)
        for i in 0..<bands.count {
            if let band = bands[i] {
                let colour = GraphView.colours[i]!
                colour.setFill()

                let context = UIGraphicsGetCurrentContext()!
                let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.genericRGBLinear),
                                          colors: [UIColor.clear.cgColor, colour.withAlphaComponent(0.5).cgColor] as CFArray,
                                          locations: nil)!

                for a in band.fadeInAreas {
                    let a1 = UIBezierPath(cgPath: a.cgPath)
                    a1.apply(transform)
                    context.saveGState()
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

        for y in yStride {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: xStart, y: y))
            path.addLine(to: CGPoint(x: xEnd, y: y))
            path.apply(transform)
            if Int(y) % 100 == 0 {
                UIColor.gray.withAlphaComponent(0.5).setStroke()
            } else {
                UIColor.lightGray.withAlphaComponent(0.25).setStroke()
            }
            path.lineWidth = 0.5
            path.stroke()
        }

        for x in xStride {
            guard xStart ... xEnd ~= x else {
                continue
            }
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: yHeight))
            path.apply(transform)
            path.lineWidth = 0.5
            if Int(x) % 7 == 0 {
                UIColor.gray.withAlphaComponent(0.5).setStroke()
            } else {
                UIColor.lightGray.withAlphaComponent(0.25).setStroke()
            }
            path.stroke()
        }


    }

}
