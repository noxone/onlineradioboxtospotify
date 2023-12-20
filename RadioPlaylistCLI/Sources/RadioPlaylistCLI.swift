// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import Foundation
import Logging
import ArgumentParser
import RadioPlaylistLib

fileprivate let logger = Logger(label: "RadioPlaylistCLI")

@main
struct RadioPlaylistCLI: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "The file where to store or load the credentials.", completion: .file(), transform: { URL(filePath: $0, directoryHint: .notDirectory) })
    var credentialsFilePath: URL = URL(filePath: "spotify.credentials", directoryHint: .notDirectory)
    @Option(name: [.long, .customShort("t")], help: "The file location of the track cache.", completion: .file(), transform: { URL(filePath: $0, directoryHint: .notDirectory) })
    var trackCacheFilePath: URL = URL(filePath: "trackcache.json", directoryHint: .notDirectory)
    
    @Option(help: "A redirect URL configured at Spotify that may be used for your app.", transform: {URL(string: $0)})
    var spotifyRedirectUriForLogin: URL?
    @Option(help: "The URL Spotify redirected you to after authorizing the app.", transform: {URL(string: $0)})
    var spotifyRedirectUriAfterLogin: URL?

    @Option(name: .customLong("client-id"), help: "The Client-ID for your Spotify app") 
    var spotifyClientId: String?
    @Option(name: .customLong("client-secret"), help: "The Client-Secret for your Spotify app")
    var spotifyClientSecret: String?

    @Option(name: .shortAndLong, help: "The ID of the radio station for analyze")
    var radioStation: String
    @Option(name: .shortAndLong, help: "Number of days to look in the past for tracks")
    var daysInPast: Int = 6
    @Option(name: .shortAndLong, help: "The name of the playlist where to store the extracted tracks")
    var playlistName: String
    @Flag
    var publicPlaylist: Bool = false
    
    
//
//    @Option var ignoreTrackIds: [String] = []

    @Flag(name: .long, help: "If actived the CLI will read all sensitive information from STD-IN instead using parameters.") var readFromStdIn: Bool = false

    mutating func validate() throws {
        if readFromStdIn {
            try readInputFromStdIn()
        }
        
        guard !radioStation.isEmpty else {
            throw ValidationError("Radio station must not be empty.")
        }
        guard !playlistName.isEmpty else {
            throw ValidationError("The playlist name must not be empty.")
        }
        guard daysInPast >= 0 else {
            throw ValidationError("Number of days to parse must be 0 or bigger.")
        }
        
        
    }
    
    mutating func readInputFromStdIn() throws {
        print("Please enter your Spotify client id:")
        spotifyClientId = readLine(strippingNewline: true) ?? ""
        print("Please enter your Spotify client secret:")
        spotifyClientSecret = readLine(strippingNewline: true) ?? ""
    }
    
    mutating func run() async throws {
        let builder = SpotifyBuilder(
            clientId: spotifyClientId ?? "",
            clientSecret: spotifyClientSecret ?? "",
            credentialsFilePath: credentialsFilePath,
            spotifyRedirectUriForLogin: URL(string: "http://localhost:7000"),//spotifyRedirectUriForLogin,
            spotifyRedirectedUriAfterLogin: spotifyRedirectUriAfterLogin
        )
        let authResult = try await builder.createSpotifyApi()
        
        if let url = authResult.redirectUri {
            throw CleanExit.message("Spotify needs your action to authorize the use of this app.\nPlease visit: \(url)\n\nAfter that start this tool again and give the redirected URL as parameter '--spotify-redirect-uri-after-login'")
        }
        
        if let spotifyApi = authResult.spotifyApi {
            let input = Input(
                station: radioStation,
                daysInPast: daysInPast,
                playlist: playlistName,
                playlistShallBePublic: false,
                maxPlaylistItems: 0,
                trackIdsToIgnore: ["288254391476651696", "936772812185958052"]
            )
            print("Track cache location: ", trackCacheFilePath.absoluteString)
            let converter = OnlineradioboxToSpotifyConverter(spotifyApi: spotifyApi, usingCacheIn: trackCacheFilePath)
            try await converter.doDownloadAndConversion(for: input)
        }
    }
}

protocol InputProvider {
    var spotifyClientId: String { get }
    var spotifyClientSecret: String { get }
    var spotifyRedirectUri: String { get }
}
