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
    @IBOutlet weak var cameraButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

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

    // MARK - Upload manager

    private lazy var uploadManager: UploadManager = {

        let documentsDirURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        let uploadsDirURL = documentsDirURL.URLByAppendingPathComponent("uploads")

        let uploadManager = UploadManager(uploadsDirectoryURL: uploadsDirURL)

        uploadManager.onUploadDidStart = { [weak self] in
            dispatch_async(dispatch_get_main_queue()) {

                UIApplication.sharedApplication().networkActivityIndicatorVisible = true

                let hasPendingUploads = uploadManager.pendingUploads.count > 0
                if hasPendingUploads {
                    self?.statusLabel.text = "Upload started. \(uploadManager.pendingUploads.count) pending..."
                }
                else {
                    self?.statusLabel.text = "Upload started..."
                }
            }
        }

        uploadManager.onUploadDidComplete = { [weak self] in
            dispatch_async(dispatch_get_main_queue()) {

                let hasPendingUploads = uploadManager.pendingUploads.count > 0
                UIApplication.sharedApplication().networkActivityIndicatorVisible = hasPendingUploads

                if hasPendingUploads {
                    self?.statusLabel.text = "Upload complete. \(uploadManager.pendingUploads.count) pending..."
                }
                else {
                    self?.statusLabel.text = "No pending uploads."
                }
            }
        }

        uploadManager.onUploadDidFail = { [weak self] error in
            dispatch_async(dispatch_get_main_queue()) {
                self?.statusLabel.text = "Upload failed. Retrying after delay..."
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            }
        }

        return uploadManager
    }()

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
                statusLabel.text = "Ready!"
                cameraButton.hidden = false
                ready()

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

    func ready() {
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: nil) { [weak uploadManager] notif in
            uploadManager?.refreshUploads()
        }
        showCamera()
    }

    @IBAction func showCamera() {
        guard presentedViewController == nil else {
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

    func showErrorAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .Cancel, handler: nil))
        presentViewController(alertController, animated: true, completion: nil)
    }

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {

        statusLabel.text = "Saving image..."

        dismissViewControllerAnimated(true) {

            guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
                return self.showErrorAlert("Image Error", message: "Unable to acquire image.")
            }

            guard let location = self.locationManager.location else {
                return self.showErrorAlert("Location Error", message: "Unable to aquire location.")
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

            if let data = resizedImage.asDataWithMetadata(metadata, mimetype: mimetype, location: location, heading: self.locationManager.heading) {

                let dateFormatter = NSDateFormatter()
                dateFormatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
                let dateString = dateFormatter.stringFromDate(NSDate()) as String

                let characterSet = NSCharacterSet.alphanumericCharacterSet().invertedSet
                let deviceName = UIDevice.currentDevice().name.componentsSeparatedByCharactersInSet(characterSet).joinWithSeparator("_")

                do {
                    try self.uploadManager.addImage(data, filename: "\(dateString)_\(deviceName).jpg")
                    self.showCamera()
                } catch {
                    return self.showErrorAlert("Image Error", message: "Unable to save image.")
                }
            }
            else {
                self.showErrorAlert("Image Error", message: "Unable to save image.")
            }

        }
    }

    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(false) {

        }
    }
}



