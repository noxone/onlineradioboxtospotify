//
//  File.swift
//  OnlineRadioBoxToSpotify
//
//  Created by Olaf Neumann on 11.12.23.
//

import Foundation
import Logging

fileprivate let logger = Logger(label: "Converter")

class OnlineradioboxToSpotifyConverter {
    private let trackCache = TrackCache.shared
    private let orb = OnlineradioBox()
    private let trackManager = TrackManager()
    private let spotify = Spotify()
    
    init() async throws {
        try await spotify.logInToSpotify()
    }
    
    func doDownloadAndConversion(for input: Input) async throws {
        try await doDownloadAndConversion(forStation: input.station, forTheLastDays: input.daysInPast, andUploadToSpotifyPlaylist: input.playlist)
    }
    
    private func doDownloadAndConversion(forStation station: String, forTheLastDays days: Int, andUploadToSpotifyPlaylist playlistName: String) async throws {
        logger.info("Starting conversion application for station '\(station)' for \(days) day(s).")
        
        let orbPlaylist = try await orb.loadPlaylist(forStation: station, forTheLastDays: days)
        logger.info("Downloaded \(orbPlaylist.count) playlist items")
        
        for playlistEntry in orbPlaylist {
            if let id = orb.extractId(from: playlistEntry) {
                await trackCache.updateEntry(withId: id, addDisplayName: playlistEntry.display)
            }
        }
        try await trackCache.storeCache()
        let count = await trackCache.count
        logger.info("Persisted cache. Cache contains \(count) items.")
    }
}
