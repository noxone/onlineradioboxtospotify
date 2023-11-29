//
//  File.swift
//  
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation

struct Input: Codable {
    let station: String
}

struct Output: Codable {
    let result: String
    let items: Int
}

struct RawPlaylistEntry {
    let time: String
    let href: String
}

struct ORBTrack {
    let name: String
    let artist: String
    let albumName: String?
}


enum ORBTSError: LocalizedError {
    case unableToLoadPage
    case invalidResponseType
    case downloadFailed
    case unableToBuildUrl(station: String)
}

