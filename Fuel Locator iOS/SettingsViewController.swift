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

    let defaults = UserDefaults.standard

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    @IBOutlet weak var defaultProductpickerView: UIPickerView!

    @IBAction func done(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView {
        case defaultProductpickerView:
            return products.count
        default:
            return 0
        }
    }

    lazy var products = Product.all.values.sorted(by: { $0.ident < $1.ident })
    lazy var regions = Region.all.values.sorted(by: { $0.ident < $1.ident })

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView {
        case defaultProductpickerView:
            return products[row].knownType.fullName ?? products[row].name
        default:
            return nil
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView {
        case defaultProductpickerView:
            MapViewController.instance!.globalProduct = products[row]
        default:
            return
        }
    }

    @IBAction func changeFieldDidEndEditing(_ sender: UITextField) {
        if let val = Float(sender.text ?? "X") {
            defaults.set(val / 100.0, forKey: "notification.priceChange")
            defaults.synchronize()
            FLOCloud.shared.changeSubscription()
        }
    }

    @IBAction func newDateSelected(_ sender: UIDatePicker) {
        MapViewController.instance!.globalDate = sender.date
    }

    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var productPicker: UIPickerView!

    static let calendar = Calendar.current
    
    @IBAction func brandDiscountSwitchSet(_ sender: UISwitch, forEvent event: UIEvent) {
        guard let brandType = Brand.Known(rawValue: Int16(sender.tag)) else {
            return
        }
        guard let brand = Brand.all[brandType.rawValue] else {
            return
        }
        brand.useDiscount = sender.isOn
        MapViewController.instance?.refresh()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        productPicker.dataSource = self
        productPicker.delegate = self

        datePicker.date = MapViewController.instance!.globalDate
    }

    override func viewDidAppear(_ animated: Bool) {
        datePicker.maximumDate = SettingsViewController.calendar.date(byAdding: .day, value: 1, to: Date())
        datePicker.date = MapViewController.instance?.globalDate ?? Date()
        if MapViewController.instance?.globalProduct != nil {
            productPicker.selectRow(products.index(of: (MapViewController.instance?.globalProduct!)!)!, inComponent: 0, animated: false)
        }
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
