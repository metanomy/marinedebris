//
//  LogFile.swift
//  TrashCam
//
//  Created by Justin Driscoll on 9/24/15.
//  Copyright © 2015 Makalu, Inc. All rights reserved.
//

import Foundation

private class FileOutputStream: OutputStreamType {

    let path: String

    init?(path: String) {
        self.path = path
    }

    func write(string: String) {
        let file = fopen(path, "a")
        if file == nil { return }
        fputs(string, file)
        fclose(file)
    }
}

private let stream = FileOutputStream(path: LogFile.path())

func printlog(items: Any...) {
    let s = items.map { String($0) }.joinWithSeparator(" ")
    print (s)
    guard var stream = stream else {
        return
    }
    print(s, toStream: &stream)
}

public struct LogFile {

    static func path() -> String {
        let libraryDirPath = NSSearchPathForDirectoriesInDomains(.LibraryDirectory, .UserDomainMask, true).first!
        return NSString(string: libraryDirPath).stringByAppendingPathComponent("log.txt")
    }

    static func read() -> String {
        do {
            return try String(contentsOfFile: path())
        } catch {
            return ""
        }
    }

    static func clear() {
        let file = fopen(path(), "w")
        if file == nil { return }
        fclose(file)
    }
}
