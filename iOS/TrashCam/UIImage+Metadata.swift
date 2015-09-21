//
//  UIImage+Metadata.swift
//  TrashCam
//
//  Created by Justin Driscoll on 9/21/15.
//  Copyright © 2015 Makalu, Inc. All rights reserved.
//

import UIKit
import MobileCoreServices
import ImageIO
import CoreLocation

extension UIImage {

    func asDataWithMetadata(metadata: NSDictionary, mimetype: String) -> NSData? {
        guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimetype, nil)?.takeRetainedValue() else {
            return nil
        }

        let data = NSMutableData()
        guard let image = self.CGImage, let destination = CGImageDestinationCreateWithData(data, uti, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, metadata)
        if !CGImageDestinationFinalize(destination) {
            print("Unable to finalize")
            return nil
        }
        return data
    }

    func asDataWithMetadata(metadata: NSDictionary, mimetype: String, location: CLLocation, heading: CLHeading?) -> NSData? {
        guard let metadata = metadata.mutableCopy() as? NSMutableDictionary else {
            return nil
        }

        let latitudeRef = location.coordinate.latitude < 0 ? "S" : "N"
        metadata.setValue(abs(location.coordinate.latitude), forKey: kCGImagePropertyGPSLatitude as String)
        metadata.setValue(latitudeRef, forKey: kCGImagePropertyGPSLatitudeRef as String)

        let longitudeRef = location.coordinate.longitude < 0 ? "W" : "E"
        metadata.setValue(abs(location.coordinate.longitude), forKey: kCGImagePropertyGPSLongitude as String)
        metadata.setValue(longitudeRef, forKey: kCGImagePropertyGPSLongitudeRef as String)

        let altitudeRef = location.altitude < 0 ? 1 : 0
        metadata.setValue(location.altitude, forKey: kCGImagePropertyGPSAltitude as String)
        metadata.setValue(altitudeRef, forKey: kCGImagePropertyGPSAltitudeRef as String)

        metadata.setValue(dateFormatters.date.stringFromDate(location.timestamp), forKey: kCGImagePropertyGPSTimeStamp as String)
        metadata.setValue(dateFormatters.time.stringFromDate(location.timestamp), forKey: kCGImagePropertyGPSDateStamp as String)

        if let heading = heading {
            metadata.setValue(heading.trueHeading, forKey: kCGImagePropertyGPSImgDirection as String)
            metadata.setValue("T", forKey: kCGImagePropertyGPSImgDirectionRef as String)
        }

        return asDataWithMetadata(metadata, mimetype: mimetype)
    }
}

private struct ISODateFormatters {

    static let ISO_DATE_FORMAT = "yyyy-MM-dd"
    static let ISO_TIME_FORMAT = "HH:mm:ss.SSSSSS"

    let date: NSDateFormatter
    let time: NSDateFormatter

    init() {
        let timeZone = NSTimeZone(abbreviation: "UTC")

        date = NSDateFormatter()
        date.timeZone = timeZone
        date.dateFormat = ISODateFormatters.ISO_DATE_FORMAT

        time = NSDateFormatter()
        time.timeZone = timeZone
        time.dateFormat = ISODateFormatters.ISO_TIME_FORMAT
    }
}

private let dateFormatters = ISODateFormatters()



