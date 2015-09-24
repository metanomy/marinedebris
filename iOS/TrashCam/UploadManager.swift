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
        printlog("Add image:", filename)

        let fileURL = uploadsDirectoryURL.URLByAppendingPathComponent(filename)

        do {
            try data.writeToURL(fileURL, options: [])
        } catch {
            printlog("Unable to save file", error)
            throw error
        }

        refreshUploads()
    }

    func refreshUploads() {
        printlog("Refresh uploads called")
        dispatch_async(queue) {
            printlog("Refreshing uploads")
            do {
                self.pendingUploads = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(self.uploadsDirectoryURL, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles).sort { $0.lastPathComponent < $1.lastPathComponent }

                if let currentUpload = self.currentUpload, let index = self.pendingUploads.indexOf(currentUpload) {
                    self.pendingUploads.removeAtIndex(index)
                }

                printlog("Refreshed uploads", self.currentUpload, self.pendingUploads)
            } catch {
                printlog("Unable to list directory:", error)
            }
            self.uploadNext()
        }
    }

    private func uploadNext() {

        printlog("Upload next called")

        guard let next = pendingUploads.first, let nextPath = next.path where currentUpload == nil else {
            return
        }

        currentUpload = next
        pendingUploads.removeAtIndex(0)

        if !NSFileManager.defaultManager().fileExistsAtPath(nextPath) {
            uploadNext()
        }

        printlog("Uploading next", next, pendingUploads)

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
                        printlog("Deleting file", next)
                        try NSFileManager.defaultManager().removeItemAtURL(next)
                    } catch {
                        printlog("Unable to delete file")
                    }

                    self.onUploadDidComplete?()

                    self.uploadNext()
                }
            }

            return nil
        }
    }
}