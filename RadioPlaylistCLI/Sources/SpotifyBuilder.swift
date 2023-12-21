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
import RadioPlaylistLib

fileprivate let logger = Logger(label: "SpotifyBuilder")

class SpotifyBuilder {
    private let callback: CommandCallback
    private var credentialsFileUrl: URL
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(callback: CommandCallback, credentialsFilePath: URL) {
        self.callback = callback
        self.credentialsFileUrl = credentialsFilePath
    }
    
    func createSpotifyApi() async throws -> SpotifyAPI<AuthorizationCodeFlowManager> {
        if let authorizationManager = readAuthorizationManagerFromFile() {
            let spotifyApi = createBasicSpotifyApi(clientId: "", clientSecret: "")
            logger.info("Set authorization manager to preloaded manager.")
            spotifyApi.authorizationManager = authorizationManager
            return spotifyApi
        }
        
        let clientID = try callback.getSpotifyClientId()
        let clientSecret = try callback.getSpotifyClientSecret()
        let spotifyApi = createBasicSpotifyApi(clientId: clientID , clientSecret: clientSecret)
        if callback.isInteractive() {
            try await doInteractiveLogin(for: spotifyApi)
        } else {
            try await doNonInteractiveLogin(for: spotifyApi)
        }
        return spotifyApi
    }
    
    private func createBasicSpotifyApi(clientId: String, clientSecret: String) -> SpotifyAPI<AuthorizationCodeFlowManager> {
        let spotifyApi = SpotifyAPI(authorizationManager: AuthorizationCodeFlowManager(clientId: clientId, clientSecret: clientSecret))
        spotifyApi.authorizationManagerDidChange
            .sink(receiveValue: { self.authorizationManagerDidChange(for: spotifyApi) })
            .store(in: &cancellables)
        return spotifyApi
    }
    
    private func authorizationManagerDidChange(for spotifyApi: SpotifyAPI<AuthorizationCodeFlowManager>) {
        do {
            logger.info("Storing changed credentials in \(credentialsFileUrl.absoluteString)")
            let authManagerData = try JSONEncoder().encode(spotifyApi.authorizationManager)
            try authManagerData.write(to: credentialsFileUrl)
        } catch {
            logger.error("Unable to store credentials: \(error.localizedDescription)")
        }
    }
    
    private func doInteractiveLogin(for spotifyApi: SpotifyAPI<AuthorizationCodeFlowManager>) async throws {
        if let appRedirectUrl = try callback.getAppRedirectUrl() {
            let authUrl = spotifyApi.authorizationManager.makeAuthorizationURL(redirectURI: appRedirectUrl, showDialog: false, scopes: RadioPlaylistLib.requiredSpotifyScopes)
            
            if let authedUrl = try callback.getSpotifyRedirectUri(for: authUrl) {
                try await authorize(spotifyApi: spotifyApi, usingRedirectUri: authedUrl.absoluteString)
                return
            }
        }
        
        try callback.exit(withMessage: nil)
    }
    
    private func doNonInteractiveLogin(for spotifyApi: SpotifyAPI<AuthorizationCodeFlowManager>) async throws {
        if let spotifyAppRedirectUrl = try callback.getAppRedirectUrl(){
            let url = spotifyApi.authorizationManager.makeAuthorizationURL(redirectURI: spotifyAppRedirectUrl, showDialog: false, scopes: RadioPlaylistLib.requiredSpotifyScopes)
            try callback.exit(withMessage: "Spotify needs your action to authorize the use of this app.\nPlease visit: \(url!)\n\nAfter that start this tool again and give the redirected URL as parameter '--spotify-redirect-uri-after-login'")
        } else if let spotifyLoginRedirectedUrl = try callback.getSpotifyRedirectUri(for: nil) {
            try await authorize(spotifyApi: spotifyApi, usingRedirectUri: spotifyLoginRedirectedUrl.absoluteString)
        }
        try callback.exit(withMessage: nil)
    }
    
    private func authorize(spotifyApi: SpotifyAPI<AuthorizationCodeFlowManager>, usingRedirectUri uri: String) async throws {
        do {
            try await spotifyApi.authorizationManager.requestAccessAndRefreshTokens(redirectURIWithQuery: URL(string: uri)!).async()
        } catch {
            logger.error("Unable to authorize Spotify API")
            throw SpotifyBuilderError.unableToAuthorizeSpotifyApi(reason: error)
        }
    }
    
    private func readAuthorizationManagerFromFile() -> AuthorizationCodeFlowManager? {
        guard let data = getContentOfCredentialsFile() else {
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
    
    private func getContentOfCredentialsFile() -> Data? {
        do {
            return try Data(contentsOf: credentialsFileUrl)
        } catch {
            logger.warning("Unable to read contents of file: \(error.localizedDescription)")
            return nil
        }
    }
}

enum SpotifyBuilderError: LocalizedError {
    case unableToAuthorizeSpotifyApi(reason: Error)
    case noRedirectUriGiven
}
