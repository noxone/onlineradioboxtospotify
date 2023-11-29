//
//  File.swift
//  
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation
import SpotifyWebAPI
import Combine

let spotify = SpotifyAPI(authorizationManager: ClientCredentialsFlowManager(clientId: spotifyClientId, clientSecret: spotifyClientSecret))
private var cancellables: Set<AnyCancellable> = []


func convertToSpotify(_ tracks: [ORBTrack]) async throws -> [Track] {
    try await spotify.authorizationManager.authorize().async()
    
    let spots = try await tracks.asyncCompactMap { try await searchSpotify(forTrack: $0) }
    return spots
}

private func createPlaylist(from tracks: [Track]) async throws {
    let playlist = try await spotify.playlist("").async()
}

private func searchSpotify(forTrack track: ORBTrack) async throws -> Track? {
    let result = try await spotify.search(query: "\(track.artist) - \(track.name)", categories: [.track]).async()
    return result.tracks?.items.first
}
