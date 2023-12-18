//
//  File.swift
//  
//
//  Created by Olaf Neumann on 18.12.23.
//

import Foundation
import Combine
import SpotifyWebAPI
import Logging

fileprivate let logger = Logger(label: "SpotifyBuilder")

class SpotifyBuilder {
    private var cancellables: Set<AnyCancellable> = []
    
    
    func createSpotifyApi(clientId: String, clientSecret: String, crdentialsFilename: String) -> SpotifyAPI<AuthorizationCodeFlowManager> {
        let spotifyApi = SpotifyAPI(authorizationManager: AuthorizationCodeFlowManager(clientId: clientId, clientSecret: clientSecret))
        spotifyApi.authorizationManagerDidChange
            .sink(receiveValue: authorizationManagerDidChange)
            .store(in: &cancellables)
     
        let authorizationUrl = logIn(spotifyApi: spotifyApi)
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
    
    private func logIn(spotifyApi: SpotifyAPI<AuthorizationCodeFlowManager>, redirectUrl: URL) -> URL? {
        if let authorizationManager = readAuthorizationManagerFromFile() {
            spotifyApi.authorizationManager = authorizationManager
            logger.info("Set authorization manager to preloaded manager.")
            return nil
        }
        
        if let spotifyRedirectUri {
            return nil
        } else {
            let url = spotifyApi.authorizationManager.makeAuthorizationURL(redirectURI: redirectUrl, showDialog: false, scopes: [.playlistModifyPublic, .playlistModifyPrivate, .playlistReadPrivate, .playlistReadCollaborative])
            return 
        }
    }
    
    private func createAutorizationManager(for spotifyApi: SpotifyAPI<AuthorizationCodeFlowManager>, fromRedirectUri uri: String) async -> AuthorizationCodeFlowManager? {
        do {
            await spotifyApi.authorizationManager.requestAccessAndRefreshTokens(redirectURIWithQuery: URL(string: uri)!).async()
            return true
        } catch {
            
        }
        return nil
    }
    
    private func readAuthorizationManagerFromFile() -> AuthorizationCodeFlowManager? {
        guard let data = getContentOfCredentialsFile(withName: credentialsFilename) else {
            return nil
        }
        
        do {
            let authorizationManager = try JSONDecoder().decode(AuthorizationCodeFlowManager.self, from: data)
            return authorizationManager
        } catch {
            logger.warning("Unable to create AuthorizationManager from file content: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func getContentOfCredentialsFile(withName filename: String) -> Data? {
        let urlString = "file://\(filename)"
        guard let url = URL(string: urlString) else {
            logger.warning("Unable to construct URL from: \(urlString)")
            return nil
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            logger.warning("Unable to read contents of file: \(error.localizedDescription)")
            return nil
        }
    }
}
