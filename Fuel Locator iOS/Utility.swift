//
//  Utility.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 10/7/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import Foundation
import CoreGraphics

extension Int {
    func clamped(to range: CountableClosedRange<Int>, modulo: Int! = nil) -> Int {
        if modulo == nil || range.upperBound - range.lowerBound < modulo {
            return range ~= self ? self : self < range.lowerBound ? range.lowerBound : range.upperBound
        } else {
            var i = self
            while i < range.lowerBound {
                i += modulo
            }
            while i > range.upperBound {
                i -= modulo
            }
            return i
        }
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        if self < range.lowerBound {
            return range.lowerBound
        } else if self > range.upperBound {
            return range.upperBound
        } else {
            return self
        }
    }
}
