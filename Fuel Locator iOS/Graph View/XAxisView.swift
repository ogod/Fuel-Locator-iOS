//
//  XAxisView.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 4/6/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit

class XAxisView: UIView {

    var graphView: GraphView!

    static let form: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "Australia/Perth")
        f.dateFormat = "EEE, dd MMM yy"
        return f
    }()
    static let pStyle: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.alignment = .left
        return p
    }()
    static let font = UIFont(name: "HelveticaNeue-Thin", size: 12)!
    static let fontDark = UIFont(name: "HelveticaNeue-Thin", size: 12)!
    static let attr: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: font,
                                                     NSAttributedString.Key.paragraphStyle: pStyle,
                                                     NSAttributedString.Key.foregroundColor: UIColor.lightGray]
    static let attrDark: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: fontDark,
                                                          NSAttributedString.Key.paragraphStyle: pStyle,
                                                          NSAttributedString.Key.foregroundColor: UIColor.gray]
    static let cal = Calendar.current
    static let timeZone = TimeZone(identifier: "Australia/Perth")

    override func draw(_ rect: CGRect) {
        guard graphView?.ready ?? false else {
            return
        }

        print("Draw x axis")

        let xScale: CGFloat = (frame.width) / max(graphView.xEnd - graphView.xStart + 2, 1)

        let c = UIGraphicsGetCurrentContext()!
        c.saveGState()
        c.rotate(by: CGFloat.pi / 2)
        UIColor.red.withAlphaComponent(0.2).set()

        let transform = CGAffineTransform(scaleX: 1, y: -xScale).translatedBy(x: 0, y: -graphView.xStart + 1)
        let startDate = XAxisView.cal.date(from: DateComponents(calendar: XAxisView.cal,
                                                                timeZone: XAxisView.timeZone,
                                                                year: 2001,
                                                                month: 1,
                                                                day: 1))!

        for y in graphView.xStride {
            guard graphView.xStart ... graphView.xEnd ~= y else {
                continue
            }
            let pText = CGPoint(x: 0, y: y).applying(transform)
            let date = XAxisView.cal.date(byAdding: .day, value: Int(y), to: startDate)!
            let text = NSAttributedString(string: XAxisView.form.string(from: date), attributes: Int(y) % 7 == 0 ? XAxisView.attrDark : XAxisView.attr)
            let h = YAxisView.font.lineHeight
            var rect = text.boundingRect(with: CGSize(width: 1000, height: YAxisView.font.lineHeight),
                                        options: NSStringDrawingOptions.truncatesLastVisibleLine, context: nil).offsetBy(dx: pText.x, dy: pText.y - h/2)
            rect.size.width = 80
            text.draw(at: pText.applying(CGAffineTransform(translationX: 0, y: -h/2)))
        }

        c.restoreGState()
    }

}
