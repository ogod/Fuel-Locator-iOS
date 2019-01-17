import AppKit
import PlaygroundSupport

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

let nibFile = NSNib.Name(rawValue:"MyView")
var topLevelObjects : NSArray?

Bundle.main.loadNibNamed(nibFile, owner:nil, topLevelObjects: &topLevelObjects)
let views = (topLevelObjects as! Array<Any>).filter { $0 is NSView }

// Present the view in Playground
PlaygroundPage.current.liveView = views[0] as! NSView

let range = 1...5

for i in 0...6 {
    print(i.clamped(to: range))
}

let v = [5.0, 4.0, 3.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0]

let c = (-2...4).reduce(0, {$0 + v[$1.clamped(to: 0...8, modulo: 7)]}) / 7.0

print(c)

switch "The quick brown fox jumps over the lazy dog." {
case "/The.*/":
    print("Yes")
default:
    print("No")
}
