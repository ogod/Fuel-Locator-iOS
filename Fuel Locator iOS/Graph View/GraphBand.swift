//
//  GraphBand.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 28/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit

typealias PriceBandValue = (high: Int16, low: Int16, date: Date)
typealias PriceBandPoint = (high: CGPoint, low: CGPoint)

/// Encapsulates a percentile price brand for a fuel price graph.
///
/// The graph is made up of ten bands of percentile groups. In addition,
/// each band has a fade in zone and a fade out zone, which may also appear
/// where the data has not been collected for a period.
/// Each band also has an associated line defining the highest price for that band
class GraphBand {

    var xStart: CGFloat
    var xEnd: CGFloat
    var startDate: Date
    var endDate: Date
    var yHeight: CGFloat

    var fadeInLines = [UIBezierPath]()
    var lines = [UIBezierPath]()
    var fadeOutLines = [UIBezierPath]()
    var fadeInAreas = [UIBezierPath]()
    var fillAreas = [UIBezierPath]()
    var fadeOutAreas = [UIBezierPath]()

    static let calendar = Calendar.current
    static let referenceDate: Date = GraphBand.calendar.date(from: DateComponents(timeZone: TimeZone(identifier: "Australia/Perth"),
                                                                                  year: 2001,
                                                                                  month: 1,
                                                                                  day: 1,
                                                                                  hour: 0,
                                                                                  minute: 0,
                                                                                  second: 0,
                                                                                  nanosecond: 0))!
    static let secondsInDay: TimeInterval = 86400

    /// The x value for a given date. A unit represents 1 day.
    ///
    /// - Parameter date: the date that defines the x value
    /// - Returns: the x value
    static func xValue(_ date: Date) -> CGFloat {
        return CGFloat(date.timeIntervalSince(GraphBand.referenceDate) / GraphBand.secondsInDay)
    }

    static func date(_ x: CGFloat) -> Date {
        return Date(timeInterval: TimeInterval(x) * GraphBand.secondsInDay, since: GraphBand.referenceDate)
    }

    /// The y value for a given fuel price. A unit represents 1c, with a tenth cent resolution.
    ///
    /// - Parameter value: The fuel price
    /// - Returns: the y value
    static func yValue(_ value: Int16) -> CGFloat {
        return CGFloat(value) / 10.0
    }

    /// Create a PriceBandPoint from a tupple of PriceBandValue
    ///
    /// - Parameter value: The values to convert
    /// - Returns: The resultant tupple of points
    static func point(_ value: PriceBandValue) -> PriceBandPoint {
        return (high: CGPoint(x: xValue(value.date), y: yValue(value.high)),
                low: CGPoint(x: xValue(value.date), y: yValue(value.low)))
    }

    /// Creates a graph band segment from a sequence of
    ///
    /// - Parameter vals: the imput values used to generate the band
    init?(values vals: AnySequence<PriceBandValue>) {
        guard vals.underestimatedCount > 0 else {
            return nil
        }
        let values = Dictionary(uniqueKeysWithValues: vals.map({
            (GraphBand.calendar.date(bySettingHour: 0,
                                        minute: 0,
                                        second: 0,
                                        of: $0.date)!, $0)
        }))
        let formDate = DateFormatter()
        formDate.dateStyle = .long
        formDate.timeStyle = .none
        startDate = values.keys.min()!
        endDate = values.keys.max()!
        var points = [PriceBandPoint]()
        xStart = CGFloat.greatestFiniteMagnitude
        xEnd = 0
        yHeight = 0
        let sd = GraphBand.calendar.date(byAdding: .second, value: -1, to: startDate)!
        GraphBand.calendar.enumerateDates(startingAfter: sd,
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
                points.append(GraphBand.point(value))
            } else {
                guard points.count > 0 else {
                    return
                }
                defer {
                    points.removeAll()
                }
                switch points.count {
                case 1:
                    let fadeInHighLine = UIBezierPath()
                    let fadeOutHighLine = UIBezierPath()
                    let fadeInLowLine = UIBezierPath()
                    let fadeOutLowLine = UIBezierPath()
                    let fadeInArea = UIBezierPath()
                    let fadeOutArea = UIBezierPath()

                    let p = points.first!

                    fadeInHighLine.move(to: CGPoint(x: p.high.x-0.3333333, y: p.high.y))
                    fadeInHighLine.addLine(to: CGPoint(x: p.high.x, y: p.high.y))
                    fadeOutHighLine.move(to: CGPoint(x: p.high.x, y: p.high.y))
                    fadeOutHighLine.addLine(to: CGPoint(x: p.high.x+0.3333333, y: p.high.y))

                    fadeInHighLine.move(to: CGPoint(x: p.low.x-0.3333333, y: p.low.y))
                    fadeInHighLine.addLine(to: CGPoint(x: p.low.x, y: p.low.y))
                    fadeOutHighLine.move(to: CGPoint(x: p.low.x, y: p.low.y))
                    fadeOutHighLine.addLine(to: CGPoint(x: p.low.x+0.3333333, y: p.low.y))

                    fadeInArea.move(to: CGPoint(x: p.high.x-0.3333333, y: p.high.y))
                    fadeInArea.addLine(to: CGPoint(x: p.high.x, y: p.high.y))
                    fadeInArea.addLine(to: CGPoint(x: p.high.x, y: p.low.y))
                    fadeInArea.addLine(to: CGPoint(x: p.high.x-0.3333333, y: p.low.y))
                    fadeInArea.close()

                    fadeOutArea.move(to: CGPoint(x: p.high.x, y: p.high.y))
                    fadeOutArea.addLine(to: CGPoint(x: p.high.x+0.3333333, y: p.high.y))
                    fadeOutArea.addLine(to: CGPoint(x: p.high.x+0.3333333, y: p.low.y))
                    fadeOutArea.addLine(to: CGPoint(x: p.high.x, y: p.low.y))
                    fadeOutArea.close()

                    fadeInLines.append(fadeInHighLine)
                    fadeInLines.append(fadeInLowLine)
                    fadeOutLines.append(fadeOutHighLine)
                    fadeOutLines.append(fadeOutLowLine)
                    fadeInAreas.append(fadeInArea)
                    fadeOutAreas.append(fadeOutArea)

                default:
                    let fadeInHighLine = UIBezierPath()
                    let highLine = UIBezierPath()
                    let fadeOutHighLine = UIBezierPath()
                    let fadeInLowLine = UIBezierPath()
                    let lowLine = UIBezierPath()
                    let fadeOutLowLine = UIBezierPath()
                    let fadeInArea = UIBezierPath()
                    let area = UIBezierPath()
                    let fadeOutArea = UIBezierPath()

                    let n = points.count
                    let p1 = points[0]
                    let p2 = points[1]
                    let pn2 = points[n-2]
                    let pn1 = points[n-1]

                    fadeInHighLine.move(to: CGPoint(x: p1.high.x - (p2.high.x - p1.high.x) / 3.0,
                                                    y: p1.high.y))
                    fadeInHighLine.addLine(to: p1.high)
                    highLine.move(to: p1.high)
                    for p in points.dropFirst() {
                        highLine.addLine(to: p.high)
                    }
                    fadeOutHighLine.move(to: pn1.high)
                    fadeOutHighLine.addLine(to: CGPoint(x: pn1.high.x - (pn2.high.x - pn1.high.x) / 3.0,
                                                        y: pn1.high.y))

                    fadeInLowLine.move(to: CGPoint(x: p1.low.x - (p2.low.x - p1.low.x) / 3.0,
                                                    y: p1.low.y))
                    fadeInLowLine.addLine(to: p1.low)
                    lowLine.move(to: p1.low)
                    for p in points.dropFirst() {
                        lowLine.addLine(to: p.low)
                    }
                    fadeOutLowLine.move(to: pn1.low)
                    fadeOutLowLine.addLine(to: CGPoint(x: pn1.low.x - (pn2.low.x - pn1.low.x) / 3.0,
                                                        y: pn1.low.y))

                    fadeInArea.move(to: CGPoint(x: p1.high.x - (p2.high.x - p1.high.x) / 3.0,
                                                y: p1.high.y))
                    fadeInArea.addLine(to: CGPoint(x: p1.high.x, y: p1.high.y))
                    fadeInArea.addLine(to: CGPoint(x: p1.low.x, y: p1.low.y))
                    fadeInArea.addLine(to: CGPoint(x: p1.low.x - (p2.low.x - p1.low.x) / 3.0,
                                                  y: p1.low.y))
                    fadeInArea.close()

                    area.move(to: p1.high)
                    for p in points.dropFirst() {
                        area.addLine(to: p.high)
                    }
                    for p in points.reversed() {
                        area.addLine(to: p.low)
                    }
                    area.close()

                    fadeOutArea.move(to: CGPoint(x: pn1.high.x, y: pn1.high.y))
                    fadeOutArea.addLine(to: CGPoint(x: pn1.high.x - (pn2.high.x - pn1.high.x) / 3.0,
                                                    y: pn1.high.y))
                    fadeOutArea.addLine(to: CGPoint(x: pn1.low.x - (pn2.low.x - pn1.low.x) / 3.0,
                                                   y: pn1.low.y))
                    fadeOutArea.addLine(to: CGPoint(x: pn1.low.x, y: pn1.low.y))
                    fadeOutArea.close()

                    fadeInLines.append(fadeInHighLine)
                    lines.append(highLine)
                    fadeOutLines.append(fadeOutHighLine)
                    fadeInLines.append(fadeInLowLine)
                    lines.append(lowLine)
                    fadeOutLines.append(fadeOutLowLine)
                    fadeInAreas.append(fadeInArea)
                    fillAreas.append(area)
                    fadeOutAreas.append(fadeOutArea)
                }
                xStart = min(xStart, GraphBand.xValue(startDate))
                xEnd = max(xEnd, GraphBand.xValue(endDate))
                yHeight = max(yHeight, points.map({$0.high.y}).max()!)
            }
        }
    }
}
