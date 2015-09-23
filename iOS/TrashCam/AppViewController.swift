//
//  AppViewController.swift
//  TrashCam
//
//  Created by Justin Driscoll on 9/21/15.
//  Copyright © 2015 Makalu, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import ImageIO

class AppViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var cameraButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        progressView.hidden = true
        progressView.progress = 0
        cameraButton.hidden = true

        if UIImagePickerController.isSourceTypeAvailable(.Camera) {
            state = .RequestingLocation
        }
        else {
            state = .CameraNotAvailable
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.sharedApplication().setStatusBarStyle(UIStatusBarStyle.LightContent, animated: false)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if state == .CameraNotAvailable {
            showCameraUnavailableMessage()
        }
    }

    // MARK - State

    private let locationManager = CLLocationManager()

    internal enum State: Int, Comparable {
        case Loaded
        case CheckingNetworkAvailabliity // TODO
        case NetworkNotAvailable // TODO
        case CameraNotAvailable
        case RequestingLocation
        case RequestingLocationAuthorization
        case LocationAccessDenied
        case LocationAccessAllowed
        case WaitingForLocation
        case ReadyToTakePhoto
        case CameraCancelled
        case CameraError
        case PhotoUploading
    }

    func setState(newState: State) {
        state = newState
    }

    private var state: State = .Loaded {
        didSet {
            if oldValue == state {
                return
            }

            print("State did change:", oldValue, "->", state)

            switch state {

            case .CameraNotAvailable:
                statusLabel.text = "Camera not found"

            case .RequestingLocation:
                locationManager.delegate = self
                locationManager.desiredAccuracy = kCLLocationAccuracyBest

            case .RequestingLocationAuthorization:
                statusLabel.text = "Requesting location access..."
                locationManager.requestWhenInUseAuthorization()

            case .LocationAccessDenied:
                statusLabel.text = "Location access denied"
                locationManager.stopUpdatingLocation()
                showLocationUnavailableMessage()

            case .LocationAccessAllowed:
                startUpdatingLocation()

            case .WaitingForLocation:
                statusLabel.text = "Getting your location..."
                locationManager.startUpdatingLocation()

            case .ReadyToTakePhoto:
                previewImageView.image = nil
                progressView.progress = 0
                progressView.hidden = true
                cameraButton.hidden = true
                statusLabel.hidden = true
                showCamera()

            case .CameraCancelled:
                statusLabel.hidden = true
                cameraButton.hidden = false

            case .CameraError:
                statusLabel.hidden = true
                cameraButton.hidden = false

            case .PhotoUploading:
                cameraButton.hidden = true
                statusLabel.hidden = false
                statusLabel.text = "Uploading image..."
                progressView.hidden = false
                progressView.hidden = false
                progressView.progress = 0

            default:
                break
            }
        }
    }

    func startUpdatingLocation() {
        if state == .LocationAccessDenied || state > State.LocationAccessAllowed {
            return
        }
        state = .WaitingForLocation
    }

    @IBAction func showCamera() {
        guard state == .ReadyToTakePhoto || state == .CameraCancelled else {
            return
        }
        let controller = UIImagePickerController()
        controller.sourceType = .Camera
        controller.cameraFlashMode = .Auto
        controller.allowsEditing = false
        controller.delegate = self
        presentViewController(controller, animated: true, completion: nil)
    }
}

// Simple operator functions to simplify state comparisons
internal func <(lhs: AppViewController.State, rhs: AppViewController.State) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

internal func ==(lhs: AppViewController.State, rhs: AppViewController.State) -> Bool {
    return lhs.rawValue == rhs.rawValue
}


// MARK - Location manager delegate
extension AppViewController: CLLocationManagerDelegate {

    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .NotDetermined:
            state = .RequestingLocationAuthorization
        case .Restricted,
        .Denied:
            state = .LocationAccessDenied
        default:
            state = .LocationAccessAllowed
        }
    }

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let _ = locations.last where state < .ReadyToTakePhoto {
            state = .ReadyToTakePhoto
        }
    }
}


// MARK - Alerts
extension AppViewController {

    private final func canOpenSettings() -> Bool {
        guard let url = NSURL(string: UIApplicationOpenSettingsURLString) else {
            return false
        }
        return UIApplication.sharedApplication().canOpenURL(url)
    }

    private final func showLocationUnavailableMessage() {

        let alertController = UIAlertController(title: "Location Unavailable", message: "Please enable location access.", preferredStyle: .Alert)

        alertController.addAction(UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil))

        if canOpenSettings() {
            alertController.addAction(UIAlertAction(title: "Open Settings", style: .Default, handler: { action in
                if let url = NSURL(string: UIApplicationOpenSettingsURLString) {
                    UIApplication.sharedApplication().openURL(url)
                }
            }))
        }

        presentViewController(alertController, animated: true, completion: nil)
    }

    private final func showCameraUnavailableMessage() {
        let alertController = UIAlertController(title: "Camera Unavailable", message: "This app requires a camera to use.", preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil))
        presentViewController(alertController, animated: true, completion: nil)
    }
}

// MARK - Image picker controller delegate
extension AppViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func uploadImageAtURL(url: NSURL) {

        state = .PhotoUploading

        let uploadRequest = AWSS3TransferManagerUploadRequest()
        uploadRequest.bucket = "marine-debris"
        uploadRequest.key = url.lastPathComponent
        uploadRequest.body = url
        uploadRequest.contentType = "image/jpeg"

        uploadRequest.uploadProgress = { bytesSent, totalBytesSent, totalBytesExpectedToSend in
            let completed = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
            dispatch_async(dispatch_get_main_queue()) {
                self.progressView.progress = Float(completed)
            }
        }

        let upload = AWSS3TransferManager.defaultS3TransferManager().upload(uploadRequest)
        upload.continueWithBlock { (task) -> AnyObject! in
            dispatch_async(dispatch_get_main_queue()) {

                if let _ = task.error {
                    let alertController = UIAlertController(title: "Upload Failed", message: "Unable to upload image. Please check your network connection and try again.", preferredStyle: .Alert)
                    alertController.addAction(UIAlertAction(title: "Retry", style: .Default, handler: { action in
                        self.uploadImageAtURL(url)
                    }))
                    alertController.addAction(UIAlertAction(title: "Dismiss", style: .Cancel, handler: { action in
                        self.state = .ReadyToTakePhoto
                    }))
                    self.presentViewController(alertController, animated: true, completion: nil)
                }

                else {
                    try! NSFileManager.defaultManager().removeItemAtURL(url)
                    self.state = .ReadyToTakePhoto
                }
            }

            return nil
        }
    }

    func showErrorAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil))
        presentViewController(alertController, animated: true, completion: nil)
    }

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {

        defer {
            dismissViewControllerAnimated(true) {
                //self.state = .LocationFound
            }
        }

        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            return showErrorAlert("Image Error", message: "Unable to save image.")
        }

        guard let location = self.locationManager.location else {
            return showErrorAlert("Location Error", message: "Unable to aquire location.")
        }

        let maxImageDimension = 2048
        let maxSize = image.sizeThatFits(CGSize(width: maxImageDimension, height: maxImageDimension))
        let resizedImage = image.resize(maxSize, quality: .High)
        let mimetype = "image/jpeg"

        var metadata: [String: AnyObject] = [:]
        if let originalMetadata = info[UIImagePickerControllerMediaMetadata]?.mutableCopy() as? NSDictionary {
            metadata = originalMetadata.mutableCopy() as! [String: AnyObject]

            // Need to strip the orientation info from the EXIF metadata because the resize
            // routine always returns the data facing up
            metadata[kCGImagePropertyOrientation as String] = nil
        }

        if let data = resizedImage.asDataWithMetadata(metadata, mimetype: mimetype, location: location, heading: locationManager.heading) {

            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
            let dateString = dateFormatter.stringFromDate(NSDate()) as String

            let characterSet = NSCharacterSet.alphanumericCharacterSet().invertedSet
            let deviceName = UIDevice.currentDevice().name.componentsSeparatedByCharactersInSet(characterSet).joinWithSeparator("_")

            let tempDirURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
            let fileURL = tempDirURL.URLByAppendingPathComponent("\(dateString)_\(deviceName).jpg")

            if !data.writeToURL(fileURL, atomically: false) {
                state = .CameraError
                return showErrorAlert("Image Error", message: "Unable to save image.")
            }
            else {
                previewImageView.image = resizedImage
                uploadImageAtURL(fileURL)
            }
        }
        else {
            state = .CameraError
            showErrorAlert("Image Error", message: "Unable to save image.")
        }
    }

    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(false, completion: nil)
        state = .CameraCancelled
    }
}



