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

                if let currentUpload = self.currentUpload, let index = self.pendingUploads.indexOf(currentUpload) {
                    self.pendingUploads.removeAtIndex(index)
                }

                print("Refreshed uploads", self.currentUpload, self.pendingUploads)
            } catch {
                print("Unable to list directory:", error)
            }
            self.uploadNext()
        }
    }

    private func uploadNext() {

        print("Upload next called")

        guard let next = pendingUploads.first where currentUpload == nil else {
            return
        }

        currentUpload = next
        pendingUploads.removeAtIndex(0)

        print("Uploading next", next, pendingUploads)

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

                    sleep(5)

                    self.refreshUploads()
                }

                else {
                    do {
                        print("Deleting file", next)
                        try NSFileManager.defaultManager().removeItemAtURL(next)
                    } catch {
                        print("Unable to delete file")
                    }

                    self.onUploadDidComplete?()

                    self.uploadNext()
                }
            }

            return nil
        }
    }
}