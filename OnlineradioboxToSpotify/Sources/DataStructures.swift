//
//  File.swift
//  
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation

struct Input: Codable {
    let station: String
    let daysInPast: Int
    let playlist: String
    let playlistShallBePublic: Bool
    let maxPlaylistItems: Int
    let trackIdsToIgnore: [String]
}

struct Output: Codable {
    let result: String
    let items: Int
}

