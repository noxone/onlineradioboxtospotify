//
//  File.swift
//  
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation
import SpotifyWebAPI
import Combine
import os.log

fileprivate let logger = Logger(subsystem: subsystem, category: "spotify")

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
            let url = URL(string: "\(FileManager.default.currentDirectoryPath)/credentials.txt")!
            logger.info("Write to: \(url.absoluteString)")
            try authManagerData.write(to: url)
        } catch {
            logger.error("Unable to store credentials: \(error.localizedDescription)")
        }
    }
    
    func logInToSpotify() async throws {
        let redirectUrl: String? = nil// ""

        if let redirectUrl {
            try await spotify.authorizationManager.requestAccessAndRefreshTokens(redirectURIWithQuery: URL(string: redirectUrl)!).async()
        } else {
            let url = spotify.authorizationManager.makeAuthorizationURL(redirectURI: URL(string: "http://localhost:7000")!, showDialog: false, scopes: [.playlistModifyPublic, .playlistModifyPrivate])
            guard let url else { fatalError("No URL created.") }
            logger.info("\(url)")
            fatalError()
        }
    }
    
    
    func convertToSpotify(_ tracks: [ORBTrack]) async throws -> [Track] {
        //try await spotify.authorizationManager.authorize().async()
        
        let spots = try await tracks.asyncCompactMap { try await searchSpotify(forTrack: $0) }
        return spots
    }
    
    func updatePlaylist(_ playlistName: String, with tracks: [Track]) async throws {
        
    }
    
    private func createPlaylist(from tracks: [Track]) async throws {
        let playlist = try await spotify.playlist("Radio/Radio Hamburg").async()
        logger.info("Playlist: \(String(describing: playlist))")
    }
    
    private func searchSpotify(forTrack track: ORBTrack) async throws -> Track? {
        let result = try await spotify.search(query: "\(track.artist) - \(track.name)", categories: [.track]).async()
        return result.tracks?.items.first
    }
}
