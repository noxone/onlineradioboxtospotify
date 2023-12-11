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
        
        logger.info("---- Loading playlist from OnlineRadioBox ----")
        let orbPlaylist = try await orb.loadPlaylist(forStation: station, forTheLastDays: days)
        logger.info("Downloaded \(orbPlaylist.count) playlist items")
        
        for playlistEntry in orbPlaylist {
            if let id = orb.extractId(from: playlistEntry) {
                await trackCache.updateEntry(withId: id, addDisplayName: playlistEntry.display, playingTime: playlistEntry.time)
            }
        }
        try await trackCache.storeCache()
        let count = await trackCache.count
        logger.info("Persisted cache. Cache contains \(count) items.")
        
        logger.info("---- Retreiving track details ----")
        let entriesWithoutTrackInfo = await trackCache.entriesWithoutTrackInfo
            .map { ORBPlaylistEntry(time: nil, display: "", href: "/track/\($0.orbId)/") }
        logger.info("Now updating \(entriesWithoutTrackInfo.count) details from OnlineRadioBox...")
        let orbTracks = try await orb.loadTrackDetails(for: entriesWithoutTrackInfo)
        logger.info("Updating cache entries...")
        for track in orbTracks {
            await trackCache.updateEntry(withId: track.id, setTitle: track.title, setArtist: track.artist)
        }
        try await trackCache.storeCache()
        logger.info("Persisted cache.")
        
        logger.info("---- Matching with spotify ----")
        let entriesWithoutSpotifyInfo = await trackCache.entriesWithoutSpotifyInfo
            .compactMap {
                SpotifyTrackRequest(id: $0.orbId, texts: Array($0.orbDisplayNames), title: $0.title, artist: $0.artist)
            }
        logger.info("Looking up \(entriesWithoutSpotifyInfo.count) entries on Spotify...")
        let spotifyTracks = try await spotify.convertToSpotify(entriesWithoutSpotifyInfo)
        logger.info("Updating cache entries...")
        for item in spotifyTracks {
            await trackCache.updateEntry(withId: item.id, setSpotifyUri: item.track.uri, setSpotifyTitle: item.track.name, setSpotifyArtist: item.track.artists?.map { $0.name }.joined(separator: ", "))
        }
        try await trackCache.storeCache()
        logger.info("Persisted cache.")
    }
}
