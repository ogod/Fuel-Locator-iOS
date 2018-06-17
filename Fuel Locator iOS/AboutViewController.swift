//
//  AboutViewController.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 17/6/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    @IBOutlet var versionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            if let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                versionLabel.text = "Version: \(version), Build: \(build)"
            }
        }
        if versionLabel.text == "Version" {
            versionLabel.text = ""
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
