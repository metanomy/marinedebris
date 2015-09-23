//
//  UploadManager.swift
//  TrashCam
//
//  Created by Justin Driscoll on 9/23/15.
//  Copyright © 2015 Makalu, Inc. All rights reserved.
//

import Foundation

enum UploadManagerError: ErrorType {
    case UnableToWriteFile
}

class UploadManager {

    let queue: dispatch_queue_t // Do everything on a serial queue

    var onUploadDidStart: (() -> Void)?
    var onUploadDidComplete: (() -> Void)?
    var onUploadDidFail: ((ErrorType) -> Void)?

    var pendingUploads: [NSURL] = []
    var currentUpload: NSURL?

    let uploadsDirectoryURL: NSURL

    init(uploadsDirectoryURL: NSURL) {
        self.queue = dispatch_queue_create("com.makaluinc.uploadmanagerqueue", DISPATCH_QUEUE_SERIAL)
        self.uploadsDirectoryURL = uploadsDirectoryURL

        if !NSFileManager.defaultManager().fileExistsAtPath(self.uploadsDirectoryURL.path!) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtURL(self.uploadsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Unable to create uploads directory")
            }
        }
    }

    func addImage(data: NSData, filename: String) throws {
        print("Add image:", filename)

        let fileURL = uploadsDirectoryURL.URLByAppendingPathComponent(filename)

        do {
            try data.writeToURL(fileURL, options: [])
        } catch {
            print("Unable to save file", error)
            throw error
        }

        refreshUploads()
    }

    func refreshUploads() {
        print("Refresh uploads called")
        dispatch_async(queue) {
            print("Refreshing uploads")
            do {
                self.pendingUploads = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(self.uploadsDirectoryURL, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles).sort { $0.lastPathComponent < $1.lastPathComponent }
            } catch {
                print("Unable to list directory:", error)
            }
            self.uploadNext()
        }
    }

    private let DELAY_ON_ERROR_SECONDS: Double = 30

    private func uploadNext() {

        print("Upload next called")

        guard let next = pendingUploads.first where currentUpload == nil else {
            return
        }

        currentUpload = next
        pendingUploads.removeAtIndex(0)

        let uploadRequest = AWSS3TransferManagerUploadRequest()
        uploadRequest.bucket = "marine-debris"
        uploadRequest.key = next.lastPathComponent
        uploadRequest.body = next
        uploadRequest.contentType = "image/jpeg"

        onUploadDidStart?()

        AWSS3TransferManager.defaultS3TransferManager().upload(uploadRequest).continueWithBlock { (task) -> AnyObject! in

            dispatch_async(self.queue) {

                self.currentUpload = nil

                if let error = task.error {

                    self.onUploadDidFail?(error)

                    let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(self.DELAY_ON_ERROR_SECONDS * Double(NSEC_PER_SEC)))
                    dispatch_after(delayTime, self.queue) {
                        self.refreshUploads()
                    }
                }

                else {
                    do {
                        try NSFileManager.defaultManager().removeItemAtURL(next)
                    } catch {
                        print("Unable to delete file")
                    }
                    self.onUploadDidComplete?()
                }

                self.uploadNext()
            }

            return nil
        }
    }
}