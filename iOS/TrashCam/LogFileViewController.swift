//
//  LogFileViewController.swift
//  TrashCam
//
//  Created by Justin Driscoll on 9/24/15.
//  Copyright © 2015 Makalu, Inc. All rights reserved.
//

import UIKit

class LogFileViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        textView.text = LogFile.read()
    }

    @IBAction func close(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil)
    }

    @IBAction func clear(sender: AnyObject) {
        LogFile.clear()
        textView.text = LogFile.read()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
