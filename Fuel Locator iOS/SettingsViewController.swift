//
//  SettingsViewController.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 5/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit
import MapKit

class SettingsViewController: UITableViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return products.count
    }

    lazy var products = Product.all.values.sorted(by: { $0.ident < $1.ident })

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return products[row].name
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        MapViewController.instance!.globalProduct = products[row]
    }

    @IBAction func newDateSelected(_ sender: UIDatePicker) {
        MapViewController.instance!.globalDate = sender.date
    }

    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var productPicker: UIPickerView!

    static let calendar = Calendar.current
    
    override func viewDidLoad() {
        super.viewDidLoad()

        productPicker.dataSource = self
        productPicker.delegate = self

        datePicker.date = MapViewController.instance!.globalDate
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        datePicker.maximumDate = SettingsViewController.calendar.date(byAdding: .day, value: 1, to: Date())
    }

    @IBAction func MapTypeSelected(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1:
            MapViewController.instance?.mapView.mapType = MKMapType.satellite

        case 2:
            MapViewController.instance?.mapView.mapType = MKMapType.hybrid

        default:
            MapViewController.instance?.mapView.mapType = MKMapType.mutedStandard
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
