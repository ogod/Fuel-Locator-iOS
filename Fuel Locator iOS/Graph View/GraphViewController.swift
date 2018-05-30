//
//  GraphViewController.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 28/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit

class GraphViewController: UIViewController {

    @IBOutlet var graphView: GraphView!

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        if let product = MapViewController.instance?.globalProduct {
            if let region = (MapViewController.instance?.mapView.annotations.first(where: {$0 is StationAnnotation}) as? StationAnnotation)?.station.suburb?.region?.first {
                Statistics.fetchAll { (stats, error) in
                    guard error == nil else {
                        print(error!)
                        return
                    }
                    let s = stats.filter({$0.product == product && $0.region == region && $0.minimum != nil})
                    self.graphView.bands.removeAll()
                    self.graphView.bands.append(GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per10!.int16Value, low: $0.minimum!.int16Value, date: $0.date)})))!)
                    self.graphView.bands.append(GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per20!.int16Value, low: $0.per10!.int16Value, date: $0.date)})))!)
                    self.graphView.bands.append(GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per30!.int16Value, low: $0.per20!.int16Value, date: $0.date)})))!)
                    self.graphView.bands.append(GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per40!.int16Value, low: $0.per30!.int16Value, date: $0.date)})))!)
                    self.graphView.bands.append(GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per50!.int16Value, low: $0.per40!.int16Value, date: $0.date)})))!)
                    self.graphView.bands.append(GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per60!.int16Value, low: $0.per50!.int16Value, date: $0.date)})))!)
                    self.graphView.bands.append(GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per70!.int16Value, low: $0.per60!.int16Value, date: $0.date)})))!)
                    self.graphView.bands.append(GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per80!.int16Value, low: $0.per70!.int16Value, date: $0.date)})))!)
                    self.graphView.bands.append(GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.per90!.int16Value, low: $0.per80!.int16Value, date: $0.date)})))!)
                    self.graphView.bands.append(GraphBand(values: AnySequence<PriceBandValue>(s.map({(high: $0.maximum!.int16Value, low: $0.per90!.int16Value, date: $0.date)})))!)
                }
            }
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
