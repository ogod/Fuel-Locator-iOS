//
//  YAxisView.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 4/6/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit

class YAxisView: UIView {

    var graphView: GraphView!

    static let form: NumberFormatter = {
        let f = NumberFormatter()
        f.positiveFormat = "##0.0"
        return f
    }()
    static let pStyle: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.alignment = .right
        return p
    }()
    static let font = UIFont(name: "HelveticaNeue-Thin", size: 12)!
    static let attr: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: font,
                                                     NSAttributedStringKey.paragraphStyle: pStyle,
                                                     NSAttributedStringKey.foregroundColor: UIColor.gray]

    override func draw(_ rect: CGRect) {
        guard graphView?.ready ?? false else {
            return
        }

        print("Draw y axis")

        let yScale: CGFloat = bounds.height / max(graphView.yHeight, 1)
        let transform = CGAffineTransform(scaleX: 1, y: -yScale).translatedBy(x: 0, y: -graphView.yHeight)

        for y in graphView.yStride {
            guard 0.01 ..< graphView.yHeight ~= y else {
                continue
            }
            let pText = CGPoint(x: bounds.width, y: y).applying(transform)
            let h = YAxisView.font.lineHeight
            let annot = NSAttributedString(string: YAxisView.form.string(from: y as NSNumber)!, attributes: YAxisView.attr)
            annot.draw(in: CGRect(x: frame.minX, y: pText.y - h/2, width: frame.width, height: h))
        }
    }

}
