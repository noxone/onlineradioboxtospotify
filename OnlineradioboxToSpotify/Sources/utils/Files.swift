//
//  File.swift
//  
//
//  Created by Olaf Neumann on 11.12.23.
//

import Foundation
import Logging

fileprivate let logger = Logger(label: "Files")

class Files {
    static let currentDirectoryString = NSString(string: FileManager.default.currentDirectoryPath)
    private static let currentDirectoryNSString = NSString(string: currentDirectoryString)
    static let currentDirectoryUrl = URL(string: String(currentDirectoryString))!
    
    static func url(forFilename filename: String) -> URL {
        let url = URL(filePath: currentDirectoryNSString.appendingPathComponent(filename), directoryHint: .notDirectory)
        logger.info("Created URL: \(url.absoluteString)")
        return url
    }
}
