//
//  GraphView.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 30/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit

class GraphView: UIView {

    var bands = [GraphBand]()

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
        guard bands.count > 0 else {
            return
        }

        let length = bands.map({$0.xLength}).max() ?? 1
        let height = bands.map({$0.xLength}).max() ?? 1
        let xScale = rect.width / length
        let yScale = rect.height / height

        for i in 0..<bands.count {
            let colour = GraphView.colours[i]!
            let band = bands[i]
            colour.setFill()
            colour.setStroke()
            for a in band.fadeInAreas {
                let a1 = (a.mutableCopy() as! UIBezierPath)
                a1.apply(CGAffineTransform(scaleX: xScale, y: yScale))
                a1.fill(with: .normal, alpha: 0.5)
            }
            for a in band.fillAreas {
                let a1 = (a.mutableCopy() as! UIBezierPath)
                a1.apply(CGAffineTransform(scaleX: xScale, y: yScale))
                a1.fill(with: .normal, alpha: 0.5)
            }
            for a in band.fadeOutAreas {
                let a1 = (a.mutableCopy() as! UIBezierPath)
                a1.apply(CGAffineTransform(scaleX: xScale, y: yScale))
                a1.fill(with: .normal, alpha: 0.5)
            }
            colour.setStroke()
            for a in band.fadeInAreas {
                let a1 = (a.mutableCopy() as! UIBezierPath)
                a1.apply(CGAffineTransform(scaleX: xScale, y: yScale))
                a1.stroke(with: .normal, alpha: 0.5)
            }
            for a in band.fillAreas {
                let a1 = (a.mutableCopy() as! UIBezierPath)
                a1.apply(CGAffineTransform(scaleX: xScale, y: yScale))
                a1.stroke(with: .normal, alpha: 0.5)
            }
            for a in band.fadeOutAreas {
                let a1 = (a.mutableCopy() as! UIBezierPath)
                a1.apply(CGAffineTransform(scaleX: xScale, y: yScale))
                a1.stroke(with: .normal, alpha: 0.5)
            }
        }
    }

}
