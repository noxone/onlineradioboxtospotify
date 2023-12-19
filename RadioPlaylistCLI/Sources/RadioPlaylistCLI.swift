// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import Foundation
import Logging
import ArgumentParser
import SpotifyWebAPI
import OnlineRadioBoxToSpotify

fileprivate let logger = Logger(label: "RadioPlaylistCLI")

@main
struct RadioPlaylistCLI: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "The file where to store or load the credentials.", completion: .file()) var credentialsFilename: String = "credentials.json"
    @Option(help: "A redirect URL configured at Spotify that may be used for your app.", transform: {URL(string: $0)}) var spotifyRedirectUriForLogin: URL?
    @Option(help: "The URL Spotify redirected you to after authorizing the app.", transform: {URL(string: $0)}) var spotifyRedirectUriAfterLogin: URL?
    
    @Flag(name: .shortAndLong, help: "If actived the CLI will read all required information from STD-IN instead using parameters.") var readRedirectUriFromStdIn: Bool = false
    
    @Argument(help: "The Client-ID for your Spotify app") var spotifyClientId: String
    @Argument(help: "The Client-Secret for your Spotify app") var spotifyClientSecret: String
    
    @Argument(help: "The ID of the radio station for analyze") var radioStation: String
    @Argument var daysInPast: Int = 6
    @Argument(help: "The name of the playlist where to store the extracted tracks") var playlistName: String
    
    @Option var ignoreTrackIds: [String] = []
    
    mutating func run() async throws {
        let messages = checkParameters()
        guard messages.isEmpty else {
            messages.forEach { print($0) }
            return
        }
        
        try await execute()
    }
    
    private func checkParameters() -> [String] {
        // TODO
        return []
    }
    
    private func execute() async throws {
        let authResult = try await SpotifyBuilder(
            clientId: spotifyClientId,
            clientSecret: spotifyClientSecret,
            credentialsFilename: credentialsFilename,
            spotifyRedirectUriForLogin: spotifyRedirectUriForLogin,
            spotifyRedirectedUriAfterLogin: spotifyRedirectUriAfterLogin
        )
            .createSpotifyApi()
        
        if let url = authResult.redirectUri {
            print("Spotify needs your action to authorize the use of this app. Please visit:")
            print(url)
            return
        }
        
        if let spotifyApi = authResult.spotifyApi {
            let input = Input(
                station: radioStation,
                daysInPast: 6,
                playlist: playlistName,
                playlistShallBePublic: false,
                maxPlaylistItems: 0,
                trackIdsToIgnore: ignoreTrackIds
            )
            let converter = OnlineradioboxToSpotifyConverter(spotifyApi: spotifyApi)
            try await converter.doDownloadAndConversion(for: input)
        }
    }
}

enum CliError : LocalizedError {
    case parameterCheckFailed
}
