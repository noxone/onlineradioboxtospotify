//
//  File.swift
//  
//
//  Created by Olaf Neumann on 20.12.23.
//

import Foundation

public struct Input: Codable {
    let station: String
    let daysInPast: Int
    let playlist: String
    let playlistShallBePublic: Bool
    let maxPlaylistItems: Int
    let trackIdsToIgnore: [String]
    
    public init(station: String, daysInPast: Int, playlist: String, playlistShallBePublic: Bool, maxPlaylistItems: Int, trackIdsToIgnore: [String]) {
        self.station = station
        self.daysInPast = daysInPast
        self.playlist = playlist
        self.playlistShallBePublic = playlistShallBePublic
        self.maxPlaylistItems = maxPlaylistItems
        self.trackIdsToIgnore = trackIdsToIgnore
    }
}

struct Output: Codable {
    let result: String
    let items: Int
}
