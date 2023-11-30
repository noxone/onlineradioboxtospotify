//
//  File.swift
//  
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation
import os.log

fileprivate let logger = Logger(subsystem: subsystem, category: "http")

class Http {
    private let urlSession = URLSession(configuration: {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30.0
        sessionConfig.timeoutIntervalForResource = 60.0
        return sessionConfig
    }())

    func downloadString(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await urlSession.data(for: request)
        guard response is HTTPURLResponse else { throw ORBTSError.invalidResponseType }
        let httpResponse = response as! HTTPURLResponse
        guard 200..<300 ~= httpResponse.statusCode else { throw ORBTSError.downloadFailed }
        logger.info("Loaded \(data.count) bytes from \(url.absoluteString)")
        if let content = String(data: data, encoding: httpResponse.encoding) {
            return content
        } else {
            throw ORBTSError.downloadFailed
        }
    }

    deinit {
        urlSession.invalidateAndCancel()
    }
}

fileprivate extension HTTPURLResponse {
    var encoding: String.Encoding {
        var usedEncoding = String.Encoding.utf8 // Some fallback value
        if let encodingName = self.textEncodingName {
            let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(encodingName as CFString))
            if encoding != UInt(kCFStringEncodingInvalidId) {
                usedEncoding = String.Encoding(rawValue: encoding)
            }
        }
        return usedEncoding
    }
}
