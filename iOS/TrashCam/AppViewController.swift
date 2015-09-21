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
    @IBOutlet weak var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        if UIImagePickerController.isSourceTypeAvailable(.Camera) {
            state = .RequestingLocation
        }
        else {
            state = .CameraNotAvailable
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
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
        case LocationFound
        case PresentingCamera
        case UploadingImage
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
            case .LocationFound:
                statusLabel.text = "Ready!"
                print("Location found", locationManager.location)
                showCamera()
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

    func showCamera() {
        guard state == .LocationFound else {
            return
        }
        state = .PresentingCamera
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
        if let _ = locations.last where state < .LocationFound {
            state = .LocationFound
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

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {

        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            print("Unable to get image")
            return
        }


        guard let metadata = info[UIImagePickerControllerMediaMetadata]?.mutableCopy() as? NSDictionary else {
            print("Missing metadata")
            return
        }

        guard let location = self.locationManager.location else {
            print("No location")
            return
        }

        let key = kCGImagePropertyGPSDictionary as String
//        metadata.setValue(location., forKey: <#T##String#>)
//        metadata[key] = self.locationManager.location

        let mimetype = "image/jpeg"
        if let data = image.asDataWithMetadata(metadata, mimetype: mimetype) {
            print("Upload image")

            let newImage = UIImage(data: data)
            imageView.image = newImage
        }
        else {
            print("NO DATA")
        }

        dismissViewControllerAnimated(true) {
            //self.state = .LocationFound
        }
    }

    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true) {
            //self.state = .LocationFound
        }
    }
}



