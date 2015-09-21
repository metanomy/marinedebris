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
}
