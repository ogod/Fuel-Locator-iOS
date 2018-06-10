//
//  ProgressViewController.swift
//  Fuel Locator iOS
//
//  Created by Owen Godfrey on 30/5/18.
//  Copyright © 2018 Owen Godfrey. All rights reserved.
//

import UIKit

class ProgressViewController: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var label: UILabel!

    var progress: Float {
        get {
            return progressView.progress
        }
        set {
            self.progressView?.setProgress(newValue, animated: true)
            if progressView != nil {
                DispatchQueue.main.async {
                    self.progressView.setProgress(newValue, animated: true)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                    self.progress = newValue
                }
            }
        }
    }

    var heading: String? {
        get {
            return label?.text
        }
        set {
            if label != nil {
                DispatchQueue.main.async {
                    self.label?.text = newValue
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                    self.heading = newValue
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
