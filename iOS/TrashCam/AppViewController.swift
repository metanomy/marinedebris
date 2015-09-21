//
//  AppViewController.swift
//  TrashCam
//
//  Created by Justin Driscoll on 9/21/15.
//  Copyright © 2015 Makalu, Inc. All rights reserved.
//

import UIKit
import CoreLocation


class AppViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        if canShowCamera() {
            state = .CameraAvailable
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

        if !canShowCamera() {
            showCameraUnavailableMessage()
        }
    }

    // MARK - State

    private let locationManager = CLLocationManager()

    enum State: Int, Comparable {
        case Loaded
        case CameraNotAvailable
        case CameraAvailable
        case RequestingLocationAuthorizationStatus
        case LocationAccessDenied
        case LocationAccessAllowed
        case WaitingForLocation
        case LocationFound
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
            case .CameraAvailable:
                locationManager.delegate = self
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
            case .RequestingLocationAuthorizationStatus:
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
                //showCamera()
            default:
                break
            }
        }
    }

    func startUpdatingLocation() {
        if state > State.LocationAccessAllowed {
            return
        }
        state = .WaitingForLocation
    }
}

// Simple operator functions to simplify comparisons
func <(lhs: AppViewController.State, rhs: AppViewController.State) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

func ==(lhs: AppViewController.State, rhs: AppViewController.State) -> Bool {
    return lhs.rawValue == rhs.rawValue
}


// MARK - Location manager delegate
extension AppViewController: CLLocationManagerDelegate {

    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .NotDetermined:
            state = .RequestingLocationAuthorizationStatus
        case .Restricted,
        .Denied:
            state = .LocationAccessDenied
        default:
            state = .LocationAccessAllowed
        }
    }

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let _ = locations.last {
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


// MARK - Image picker controller

extension AppViewController {

    func canShowCamera() -> Bool {
        return UIImagePickerController.isSourceTypeAvailable(.Camera)
    }

    func showCamera() {

        guard canShowCamera() else {
            locationManager.stopUpdatingLocation()
            return
        }

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


// MARK - Image picker controller delegate
extension AppViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {

    }

    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }
}



