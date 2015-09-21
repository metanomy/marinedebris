//
//  AppViewController.swift
//  TrashCam
//
//  Created by Justin Driscoll on 9/21/15.
//  Copyright © 2015 Makalu, Inc. All rights reserved.
//

import UIKit
import CoreLocation

class AppViewController: UIViewController, CLLocationManagerDelegate {

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "appWillEnterForeground:", name: UIApplicationWillEnterForegroundNotification, object: nil)

        checkLocationAuthorization()
    }

    // MARK - Location

    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?

    private var userLocationAuthorized = false {
        didSet {
            if oldValue == userLocationAuthorized {
                return
            }

            if userLocationAuthorized {
                locationManager.startUpdatingLocation()
            }
            else {
                locationManager.stopUpdatingLocation()
            }
        }
    }

    private final func checkLocationAuthorization() {
        switch CLLocationManager.authorizationStatus() {
        case .Restricted,
             .Denied:
            showLocationAuthorizationUnavailableMessage()
        case .NotDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            userLocationAuthorized = true
        }
    }
}

// MARK - Notifications

extension AppViewController {

    func appWillEnterForeground(notification: NSNotification) {
        checkLocationAuthorization()
    }
}

// MARK - Location manager delegate

extension AppViewController {

    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        self.userLocationAuthorized = status == .AuthorizedWhenInUse || status == .AuthorizedAlways
    }

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("Did update location", locations)
        currentLocation = locations.last
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

    private final func showLocationAuthorizationUnavailableMessage() {

        print("Location authorization restricted.")

        let alertController = UIAlertController(title: "Location Access Restricted", message: "Please enable location access.", preferredStyle: .Alert)

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
}



