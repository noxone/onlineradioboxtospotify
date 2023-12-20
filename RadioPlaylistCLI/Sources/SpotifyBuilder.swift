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
    private let inputProvider: InputProvider
    private var credentialsFileUrl: URL
    private var spotifyRedirectUriForLogin: URL?
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(inputProvider: InputProvider, credentialsFilePath: URL, spotifyRedirectUriForLogin: URL?) {
        self.inputProvider = inputProvider
        self.credentialsFileUrl = credentialsFilePath
        self.spotifyRedirectUriForLogin = spotifyRedirectUriForLogin
    }
    
    private func createBasicSpotifyApi(clientId: String, clientSecret: String) -> SpotifyAPI<AuthorizationCodeFlowManager> {
        let spotifyApi = SpotifyAPI(authorizationManager: AuthorizationCodeFlowManager(clientId: inputProvider.getSpotifyClientId(), clientSecret: inputProvider.getSpotifyClientSecret()))
        spotifyApi.authorizationManagerDidChange
            .sink(receiveValue: { self.authorizationManagerDidChange(for: spotifyApi) })
            .store(in: &cancellables)
        return spotifyApi
    }
    
    func createSpotifyApi() async throws -> SpotifyAPI<AuthorizationCodeFlowManager> {
        if let authorizationManager = readAuthorizationManagerFromFile() {
            var spotifyApi = createBasicSpotifyApi(clientId: "", clientSecret: "")
            logger.info("Set authorization manager to preloaded manager.")
            spotifyApi.authorizationManager = authorizationManager
            return spotifyApi
        }
        
        let spotifyApi = createBasicSpotifyApi(clientId: inputProvider.getSpotifyClientId(), clientSecret: inputProvider.getSpotifyClientSecret())
        let authorizationUrl = try await logIn(spotifyApi: spotifyApi)
        
        if let authorizationUrl {
            return (spotifyApi: nil, redirectUri: authorizationUrl)
        } else {
            return (spotifyApi: spotifyApi, redirectUri: nil)
        }
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
    
    private func logIn(spotifyApi: SpotifyAPI<AuthorizationCodeFlowManager>) async throws -> URL? {
        if let spotifyRedirectedUriAfterLogin = try inputProvider.getSpotifyRedirectUri() {
            try await authorize(spotifyApi: spotifyApi, usingRedirectUri: spotifyRedirectedUriAfterLogin.absoluteString)
            return nil
        } else if let spotifyRedirectUriForLogin {
            let url = spotifyApi.authorizationManager.makeAuthorizationURL(redirectURI: spotifyRedirectUriForLogin, showDialog: false, scopes: [.playlistModifyPublic, .playlistModifyPrivate, .playlistReadPrivate, .playlistReadCollaborative])
            return url
        } else {
            throw SpotifyBuilderError.noRedirectUriGiven
        }
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
