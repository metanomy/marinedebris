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
        UIApplication.sharedApplication().statusBarStyle = .Default
        textView.text = LogFile.read()
    }
    
    @IBAction func close(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil)
    }

    @IBAction func clear(sender: AnyObject) {
        LogFile.clear()
        textView.text = LogFile.read()
    }
    
    @IBAction func upload(sender: AnyObject) {

        guard let text = textView.text else {
            return
        }

        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
        let dateString = dateFormatter.stringFromDate(NSDate()) as String

        let characterSet = NSCharacterSet.alphanumericCharacterSet().invertedSet
        let deviceName = UIDevice.currentDevice().name.truncate(40).componentsSeparatedByCharactersInSet(characterSet).joinWithSeparator("_")

        let data = text.dataUsingEncoding(NSUTF8StringEncoding)!

        let filename = "\(dateString)_\(deviceName).log"
        let url = NSURL(fileURLWithPath: NSString(string: NSTemporaryDirectory()).stringByAppendingPathComponent(filename))
        data.writeToURL(url, atomically: false)

        let uploadRequest = AWSS3TransferManagerUploadRequest()
        uploadRequest.bucket = "marine-debris"
        uploadRequest.key = "log/\(filename)"
        uploadRequest.body = url
        uploadRequest.contentType = "text/plain"

        AWSS3TransferManager.defaultS3TransferManager().upload(uploadRequest).continueWithBlock { (task) -> AnyObject! in

            if let error = task.error {
                printlog("Log upload failed", error)
            }

            else {
                printlog("Log uploaded successfully")
            }

            dispatch_async(dispatch_get_main_queue()) {
                self.textView.text = LogFile.read()
            }
            
            return nil
        }
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
