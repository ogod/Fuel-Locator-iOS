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

    @IBOutlet var brandSwitches: [UISwitch]!
    @IBOutlet weak var notificationproductPickerView: UIPickerView!
    @IBOutlet weak var notificationRegionPickerView: UIPickerView!
    @IBOutlet weak var defaultProductpickerView: UIPickerView!
    @IBOutlet weak var priceChangeTextView: UITextField!

    @IBAction func done(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView {
        case defaultProductpickerView, notificationproductPickerView:
            return products.count
        case notificationRegionPickerView:
            return regions.count
        default:
            return 0
        }
    }

    lazy var products = Product.all.values.sorted(by: { $0.ident < $1.ident })
    lazy var regions = Region.all.values.sorted(by: { $0.ident < $1.ident })

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView {
        case defaultProductpickerView, notificationproductPickerView:
            return products[row].knownType.fullName ?? products[row].name
        case notificationRegionPickerView:
            return regions[row].name
        default:
            return nil
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView {
        case defaultProductpickerView:
            MapViewController.instance!.globalProduct = products[row]
        case notificationproductPickerView:
            defaults.set(products[row].ident, forKey: "notification.product")
            defaults.synchronize()
            FLOCloud.shared.changeSubscription()
        case notificationRegionPickerView:
            defaults.set(regions[row].ident, forKey: "notification.region")
            defaults.synchronize()
            FLOCloud.shared.changeSubscription()
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
        notificationproductPickerView.dataSource = self
        notificationRegionPickerView.dataSource = self
        notificationproductPickerView.delegate = self
        notificationRegionPickerView.delegate = self

        datePicker.date = MapViewController.instance!.globalDate

        for sw in brandSwitches {
            if let br = Brand.Known(rawValue: Int16(sw.tag)) {
                sw.isOn = UserDefaults.standard.bool(forKey: br.key)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        datePicker.maximumDate = SettingsViewController.calendar.date(byAdding: .day, value: 1, to: Date())
        datePicker.date = MapViewController.instance?.globalDate ?? Date()
        if MapViewController.instance?.globalProduct != nil {
            productPicker.selectRow(products.index(of: (MapViewController.instance?.globalProduct!)!)!, inComponent: 0, animated: false)
        }
        let notProd = defaults.integer(forKey: "notification.product")
        let notReg = defaults.integer(forKey: "notification.region")
        let notPrice = defaults.float(forKey: "notification.priceChange")
        notificationproductPickerView.selectRow(products.index(of: (products.first(where: {$0.ident == notProd}))!)!, inComponent: 0, animated: false)
        notificationRegionPickerView.selectRow(regions.index(of: (regions.first(where: {$0.ident == notReg}))!)!, inComponent: 0, animated: false)
        priceChangeTextView.text = String(Int(notPrice*100))
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
