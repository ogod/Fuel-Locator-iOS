//
//  GraphSevenDayAverage.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 14/6/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit

typealias PricePointValue = (value: Int16, date: Date)

class GraphSevenDayAverage {

    var xStart: CGFloat
    var xEnd: CGFloat
    var startDate: Date
    var endDate: Date
    var yHeight: CGFloat

    var fadeInLines = [UIBezierPath]()
    var lines = [UIBezierPath]()
    var fadeOutLines = [UIBezierPath]()

    private static let calendar = Calendar.current
    private static let referenceDate: Date = GraphSevenDayAverage.calendar.date(from: DateComponents(timeZone: TimeZone(identifier: "Australia/Perth"),
                                                                                          year: 2001,
                                                                                          month: 1,
                                                                                          day: 1,
                                                                                          hour: 0,
                                                                                          minute: 0,
                                                                                          second: 0,
                                                                                          nanosecond: 0))!
    private static let secondsInDay: TimeInterval = 86400

    /// The x value for a given date. A unit represents 1 day.
    ///
    /// - Parameter date: the date that defines the x value
    /// - Returns: the x value
    private func xValue(_ date: Date) -> CGFloat {
        return CGFloat(date.timeIntervalSince(GraphSevenDayAverage.referenceDate) / GraphSevenDayAverage.secondsInDay)
    }

    /// The y value for a given fuel price. A unit represents 1c, with a tenth cent resolution.
    ///
    /// - Parameter value: The fuel price
    /// - Returns: the y value
    private func yValue(_ value: Int16) -> CGFloat {
        return CGFloat(value) / 10.0
    }

    /// Create a PriceBandPoint from a tupple of PriceBandValue
    ///
    /// - Parameter value: The values to convert
    /// - Returns: The resultant tupple of points
    private func point(_ value: PricePointValue) -> CGPoint {
        return CGPoint(x: xValue(value.date), y: yValue(value.value))
    }

    /// Averages two points
    ///
    /// - Parameters:
    ///   - p1: The first point
    ///   - p2: The second point
    /// - Returns: the midpoint between the two points
    private func avPoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }

    /// Creates a graph band segment from a sequence of
    ///
    /// - Parameter vals: the imput values used to generate the band
    init?(values vals: AnySequence<PricePointValue>) {
        guard vals.underestimatedCount > 0 else {
            return nil
        }
        let values = Dictionary(uniqueKeysWithValues: vals.map({
            (GraphSevenDayAverage.calendar.date(bySettingHour: 0,
                                     minute: 0,
                                     second: 0,
                                     of: $0.date)!, $0)
        }))
        let formDate = DateFormatter()
        formDate.dateStyle = .long
        formDate.timeStyle = .none
        startDate = values.keys.min()!
        endDate = values.keys.max()!
        var points = [CGPoint]()
        xStart = CGFloat.greatestFiniteMagnitude
        xEnd = 0
        yHeight = 0
        let sd = GraphSevenDayAverage.calendar.date(byAdding: .second, value: -1, to: startDate)!
        GraphSevenDayAverage.calendar.enumerateDates(startingAfter: sd,
                                          matching: DateComponents(hour: 0, minute: 0, second: 0, nanosecond: 0),
                                          matchingPolicy: .nextTime,
                                          repeatedTimePolicy: .first,
                                          direction: .forward)
        { (date: Date!, indx: Bool, stop: inout Bool) in
            guard date <= endDate || points.count > 0 else {
                stop = true
                return
            }
            if let value = values[date] {
                points.append(point(value))
            } else {
                guard points.count > 0 else {
                    return
                }
                defer {
                    points.removeAll()
                }
                switch points.count {
                case 1:
                    let fadeInLine = UIBezierPath()
                    let fadeOutLine = UIBezierPath()

                    let p = points.first!

                    fadeInLine.move(to: CGPoint(x: p.x-0.3333333, y: p.y))
                    fadeInLine.addLine(to: CGPoint(x: p.x, y: p.y))

                    fadeInLines.append(fadeInLine)
                    fadeOutLines.append(fadeOutLine)

                default:
                    let fadeInLine = UIBezierPath()
                    let line = UIBezierPath()
                    let fadeOutLine = UIBezierPath()

                    let n = points.count
                    let p1 = points[0]
                    let p2 = points[1]
                    let pn2 = points[n-2]
                    let pn1 = points[n-1]

                    var v: [CGPoint] = points
                    for i in 0 ..< n {
                        v[i].y = (i-3 ... i+3).reduce(0.0, {$0 + points[$1.clamped(to: 0...n-1, modulo: 7)].y  / 7.0})
                    }
                    points = v

                    fadeInLine.move(to: CGPoint(x: p1.x - (p2.x - p1.x) / 3.0,
                                                y: p1.y - (p2.y - p1.y) / 3.0))
                    fadeInLine.addLine(to: p1)
                    line.move(to: points.first!)
                    for i in 0 ..< n-1 {
                        line.addQuadCurve(to: avPoint(points[i], points[i+1]), controlPoint: points[i])
                    }
                    line.addLine(to: points.last!)
                    fadeOutLine.move(to: pn1)
                    fadeOutLine.addLine(to: CGPoint(x: pn1.x - (pn2.x - pn1.x) / 3.0,
                                                    y: pn1.y - (pn2.y - pn1.y) / 3.0))

                    fadeInLines.append(fadeInLine)
                    lines.append(line)
                    fadeOutLines.append(fadeOutLine)
                }
                xStart = min(xStart, xValue(startDate))
                xEnd = max(xEnd, xValue(endDate))
                yHeight = max(yHeight, points.map({$0.y}).max()!)
            }
        }
    }
}
