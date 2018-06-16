//
//  GraphViewController.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 28/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit

class GraphViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var graphView: GraphView!
    @IBOutlet weak var xAxisView: XAxisView!
    @IBOutlet weak var yAxisView: YAxisView!
    @IBOutlet weak var graphScrollView: UIScrollView!
    @IBOutlet weak var xAxisScrollView: UIScrollView!
    @IBOutlet weak var yAxisScrollView: UIScrollView!
    @IBOutlet weak var yAxisLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var graphTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var graphTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var graphLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var graphBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var graphWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var graphHeightConstraint: NSLayoutConstraint!

    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        df.doesRelativeDateFormatting = true
        return df
    }()

    var relativeOffset: CGPoint {
        set {
            let xOffset = max(min(newValue.x, 1), 0) * (graphScrollView.contentSize.width - graphScrollView.bounds.width)
            let yOffset = max(min(newValue.y, 1), 0) * (graphScrollView.contentSize.height - graphScrollView.bounds.height)
            guard !xOffset.isNaN && !yOffset.isNaN else {
                return
            }
            graphScrollView.contentOffset = CGPoint(x: xOffset, y: yOffset)
            xAxisScrollView.contentOffset = CGPoint(x: xOffset, y: 0)
            yAxisScrollView.contentOffset = CGPoint(x: 0, y: yOffset)
        }
        get {
            let xRelOffset = (graphScrollView.contentSize.width - graphScrollView.bounds.width) / (graphScrollView.contentOffset.x)
            let yRelOffset = (graphScrollView.contentSize.height - graphScrollView.bounds.height) / (graphScrollView.contentOffset.y)
            return CGPoint(x: xRelOffset, y: yRelOffset)
        }
    }

    fileprivate func setupContentSizes() {
        let r = relativeOffset
        let width = max(graphView.width, graphScrollView.bounds.width)
        let height = max(graphView.height, graphScrollView.bounds.height)
        graphScrollView.contentSize = CGSize(width: width, height: height)
        xAxisScrollView.contentSize = CGSize(width: width, height: xAxisScrollView.bounds.height)
        yAxisScrollView.contentSize = CGSize(width: xAxisScrollView.bounds.width, height: height)
        graphWidthConstraint.constant = width
        graphHeightConstraint.constant = height
        relativeOffset = r
        graphView.setNeedsDisplay()
        xAxisView.setNeedsDisplay()
        yAxisView.setNeedsDisplay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupContentSizes()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "–––"
        yAxisLabel.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
        activityIndicator.startAnimating()
        if let product = MapViewController.instance?.globalProduct {
            if let region = MapViewController.instance?.globalRegion {
                title = view.bounds.width > 500 ?
                    "Fuel Price History for \(product.name) in the \(region.name)" :
                    "\(product.name) in \(region.name)"
                Statistics.fetchHistoric(product, region) { (stats, error) in
                    guard error == nil else {
                        print(error!)
                        return
                    }
                    self.xAxisView.graphView = self.graphView
                    self.yAxisView.graphView = self.graphView
                    self.graphView.generateBands(fromStatistics: stats)
                    self.graphView.ready = true
                    self.setupContentSizes()
                    self.relativeOffset = CGPoint(x: 1, y: 0)
                    self.activityIndicator.stopAnimating()
                    self.view.setNeedsLayout()
                }
            }
        }
    }

    @IBAction func zoom(_ sender: UIPinchGestureRecognizer) {
        graphView.xScale = round(graphView.xScale * ((sender.scale - 1) * 0.25 + 1) * 10) / 10
        view.setNeedsLayout()
    }

    @IBAction func finished(_ sender: Any) {
        self.dismiss(animated: true)
    }

    @IBAction func done(_ segue: UIStoryboardSegue) {
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func syncScrollX(from sourceScrollView: UIScrollView, to destScrollView: UIScrollView) {
        var scrollBounds = destScrollView.contentOffset
        scrollBounds.x = sourceScrollView.contentOffset.x
        destScrollView.contentOffset = scrollBounds
    }

    func syncScrollY(from sourceScrollView: UIScrollView, to destScrollView: UIScrollView) {
        var scrollBounds = destScrollView.contentOffset
        scrollBounds.y = sourceScrollView.contentOffset.y
        destScrollView.contentOffset = scrollBounds
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == graphScrollView {
            syncScrollX(from: graphScrollView, to: xAxisScrollView)
            syncScrollY(from: graphScrollView, to: yAxisScrollView)
        } else if scrollView == xAxisScrollView {
            syncScrollX(from: xAxisScrollView, to: graphScrollView)
        } else if scrollView == yAxisScrollView {
            syncScrollY(from: yAxisScrollView, to: graphScrollView)
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
