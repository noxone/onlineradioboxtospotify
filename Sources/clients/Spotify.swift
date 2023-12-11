//
//  File.swift
//  
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation
import SpotifyWebAPI
import Combine
import Logging

fileprivate let logger = Logger(label: "spotify")

class Spotify {
    
    //fileprivate let spotify = SpotifyAPI(authorizationManager: ClientCredentialsFlowManager(clientId: spotifyClientId, clientSecret: spotifyClientSecret))
    private let spotify: SpotifyAPI<AuthorizationCodeFlowManager>
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        spotify = SpotifyAPI(authorizationManager: AuthorizationCodeFlowManager(clientId: spotifyClientId, clientSecret: spotifyClientSecret))
        spotify.authorizationManagerDidChange
            .sink(receiveValue: authorizationManagerDidChange)
            .store(in: &cancellables)
    }
    
    private func authorizationManagerDidChange() {
        do {
            let authManagerData = try JSONEncoder().encode(spotify.authorizationManager)
            let url = Files.url(forFilename: "credentials.txt")
            try authManagerData.write(to: url)
        } catch {
            logger.error("Unable to store credentials: \(error.localizedDescription)")
        }
    }
    
    func logInToSpotify() async throws {
        if let url = URL(string: locationOfSecrets), let data = try? Data(contentsOf: url) {
            let authorizationManager = try JSONDecoder().decode(AuthorizationCodeFlowManager.self, from: data)
            spotify.authorizationManager = authorizationManager
            return
        }
        
        let redirectUrl: String? = nil // ""

        if let redirectUrl {
            try await spotify.authorizationManager.requestAccessAndRefreshTokens(redirectURIWithQuery: URL(string: redirectUrl)!).async()
        } else {
            let url = spotify.authorizationManager.makeAuthorizationURL(redirectURI: URL(string: "http://localhost:7000")!, showDialog: false, scopes: [.playlistModifyPublic, .playlistModifyPrivate, .playlistReadPrivate, .playlistReadCollaborative])
            guard let url else { fatalError("No URL created.") }
            logger.info("\(url)")
            fatalError()
        }
    }
    
    
    func convertToSpotify(_ tracks: [ORBTrack]) async throws -> [(id: String, track: Track)] {
        return try await tracks
            .asyncMap { try await (id: $0.id, track: searchSpotify(forTrack: $0)) }
            .filter { $0.track != nil }
            .map { (id: $0.id, track: $0.track!) }
    }
    
    func convertToSpotify(_ tracks: [SpotifyTrackRequest]) async throws -> [(id: String, track: Track)] {
        return try await tracks
            .concurrentMap { try await (id: $0.id, track: self.searchSpotify(forRequest: $0)) }
            .filter { $0.track != nil }
            .map { (id: $0.id, track: $0.track!) }
    }
    
    func updatePlaylist(uri playlistUri: String, with tracks: [Track]) async throws {
        try await updatePlaylist(uri: playlistUri, withUris: tracks.compactMap { $0.uri })
    }

    func updatePlaylist(uri playlistUri: String, withUris tracks: [String]) async throws {
        _ = try await spotify.replaceAllPlaylistItems(playlistUri, with: [] ).async()
        try await tracks.chunked(size: 100)
            .asyncForEach {
                _ = try await spotify.addToPlaylist(playlistUri, uris: $0).async()
            }
    }

    private func getPlaylist(withName name: String) async throws -> Playlist<PlaylistItemsReference>? {
        return try await spotify.currentUserPlaylists().async()
            .items
            .filter { $0.name == name }
            .first
    }
    
    func getOrCreate(playlist name: String, isPublic: Bool) async throws -> String {
        let currentUser = try await spotify.currentUserProfile().async()
        let allPlaylists = try await spotify.userPlaylists(for: currentUser.uri).async()
        let playlist = allPlaylists.items.first(where: { $0.name == name })
        if let playlist {
            return playlist.uri
        }
        let details = PlaylistDetails(name: name, isPublic: isPublic, isCollaborative: false)
        let response = try await spotify.createPlaylist(for: currentUser.uri, details).async()
        return response.uri
    }
    
    private func createPlaylist(from tracks: [Track]) async throws {
        let playlist = try await spotify.playlist("Radio/Radio Hamburg").async()
        logger.info("Playlist: \(String(describing: playlist))")
    }
    
    private func searchSpotify(forTrack track: ORBTrack) async throws -> Track? {
        return try await searchSpotify(query: "\(track.artist) - \(track.title)")
    }
    
    private func searchSpotify(forRequest request: SpotifyTrackRequest) async throws -> Track? {
        for text in request.texts {
            let track = try await searchSpotify(query: text)
            if let track {
                return track
            }
        }
        return try await searchSpotify(query: "\(request.artist ?? "") - \(request.title ?? "")")
    }
    
    private func searchSpotify(query: String) async throws -> Track? {
        let result = try await spotify.search(query: query, categories: [.track]).async()
        return result.tracks?.items.first
    }
}

struct SpotifyTrackRequest {
    let id: String
    let texts: [String]
    let title: String?
    let artist: String?
}
