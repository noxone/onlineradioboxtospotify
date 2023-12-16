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
        try await doDownloadAndConversion(forStation: input.station, forTheLastDays: input.daysInPast, andUploadToSpotifyPlaylist: input.playlist, thatShallBePublic: input.playlistShallBePublic)
    }
    
    private func doDownloadAndConversion(forStation station: String, forTheLastDays days: Int, andUploadToSpotifyPlaylist playlistName: String, thatShallBePublic playlistIsPublic: Bool) async throws {
        logger.info("Starting conversion application for station '\(station)' for \(days) day(s).")
        
        let orbPlaylist = try await loadPlaylistFromOnlineRadioBox(forStation: station, forTheLastDays: days)
        try await loadTrackDetailsFromOnlineRadioBox()
        try await matchSongsWithSpotify()
        try await updateSpotifyPlaylist(withTracksFrom: orbPlaylist, playlistName: playlistName, playlistIsPublic: playlistIsPublic, maxPlaylistItems: input.maxPlaylistItems, ignoring: input.trackIdsToIgnore)
    }
    
    private func loadPlaylistFromOnlineRadioBox(forStation station: String, forTheLastDays days: Int) async throws -> [ORBTrack] {
        logger.info("---- Loading playlist from OnlineRadioBox ----")
        let orbTracks = try await orb.loadPlaylist(forStation: station, forTheLastDays: days)
        logger.info("Downloaded \(orbTracks.count) playlist items")
        
        for track in orbTracks {
            await trackCache.updateEntry(withId: track.id, addDisplayName: track.display, playingTime: track.time)
        }
        try await trackCache.storeCache()
        let count = await trackCache.count
        logger.info("Persisted cache. Cache contains \(count) items.")
        return orbTracks
    }
    
    private func loadTrackDetailsFromOnlineRadioBox() async throws {
        logger.info("---- Retreiving track details ----")
        let entriesWithoutTrackInfo = await trackCache.entriesWithoutTrackInfo
            .map { ORBTrack(id: $0.orbId, time: nil, display: nil, title: nil, artist: nil) }
        logger.info("Now updating \(entriesWithoutTrackInfo.count) details from OnlineRadioBox...")
        let orbTracks = try await orb.loadTrackDetails(for: entriesWithoutTrackInfo)
        logger.info("Updating cache entries...")
        for track in orbTracks {
            await trackCache.updateEntry(withId: track.id, setTitle: track.title, setArtist: track.artist)
        }
        try await trackCache.storeCache()
        logger.info("Persisted cache.")
    }
    
    private func matchSongsWithSpotify() async throws {
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
    
    private func updateSpotifyPlaylist(withTracksFrom orbPlaylist: [ORBTrack], playlistName: String, playlistIsPublic: Bool, maxPlaylistItems: Int, ignoring ignoreIds: [String]) async throws {
        logger.info("---- Updating Spotify playlist ----")
        logger.info("Generating playlist content...")
        let tracklist = trackManager.generatePlaylist(fromNewInput: orbPlaylist, ignoring: ignoreIds)
        let spotifyUris = await tracklist
            .asyncMap { await trackCache.getSpotifyUri(forId: $0.id) }
            .compactMap { $0 }
            .prefix(maxPlaylistItems > 0 ? maxPlaylistItems : Int.max)
        logger.info("Creating or fetching playlist")
        let playlist = try await spotify.getOrCreate(playlist: playlistName, isPublic: playlistIsPublic)
        logger.info("Updating playlist with \(spotifyUris.count) entries.")
        try await spotify.updatePlaylist(uri: playlist.uri, withUris: Array(spotifyUris))
    }
}
