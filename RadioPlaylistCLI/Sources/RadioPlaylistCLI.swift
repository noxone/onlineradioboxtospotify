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
struct RadioPlaylistCLI: AsyncParsableCommand, CommandCallback {
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
    
    mutating func run() async throws {
        let builder = SpotifyBuilder(
            callback: self,
            credentialsFilePath: credentialsFilePath
        )
        let spotifyApi = try await builder.createSpotifyApi()
        
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
    
    private func getStdInData(forQuestion prompt: String) -> String {
        print(prompt)
        return readLine(strippingNewline: true) ?? ""
    }
    
    private func getUserInput(staticString: String?, stdInQuestion: String, validationErrorMessage: String) throws -> String {
        if let staticString {
            return staticString
        } else if readFromStdIn {
            let input = getStdInData(forQuestion: stdInQuestion)
            return input
        }
        throw ValidationError(validationErrorMessage)
    }
    
    func getSpotifyClientId() throws -> String {
        return try getUserInput(
            staticString: spotifyClientId,
            stdInQuestion: "Entry Spotify Client ID:",
            validationErrorMessage: "No Spotify Client ID specified"
        )
    }
    
    func getSpotifyClientSecret() throws -> String {
        return try getUserInput(
            staticString: spotifyClientSecret,
            stdInQuestion: "Enter Spotify Client Secret:",
            validationErrorMessage: "No Spotify Client Secret specified"
        )
    }
    
    func getAppRedirectUrl() throws -> URL? {
        if isInteractive() {
            return try URL(string: getUserInput(
                staticString: spotifyRedirectUriForLogin?.absoluteString,
                stdInQuestion: "Enter app redirect URL:",
                //transform: { URL(string: $0) },
                validationErrorMessage: "No app redirection URL specified."
            ))
        } else {
            if let spotifyRedirectUriForLogin {
                return spotifyRedirectUriForLogin
            } else if spotifyRedirectUriAfterLogin != nil {
                return nil
            }
            throw ValidationError("No app redirect URL specified")
        }
    }

    func getSpotifyRedirectUri(for redirectUri: URL?) throws -> URL? {
        if isInteractive() {
            if let redirectUri {
                print("Spotify needs your action to authorize the use of this app.\nPlease visit: \(redirectUri)\n\nAfter that please come back here.")
            }
            return try URL(string: getUserInput(
                staticString: spotifyRedirectUriAfterLogin?.absoluteString,
                stdInQuestion: "Enter redirected URL from Spotify:",
                //transform: { URL(string: $0)! },
                validationErrorMessage: "No redirection from Spotify specified"
            ))
        } else {
            if let spotifyRedirectUriAfterLogin {
                return spotifyRedirectUriAfterLogin
            }
            throw ValidationError("No redirect URL from Spotify specified")
        }
    }
    
    func isInteractive() -> Bool {
        readFromStdIn
    }
    
    func exit(withMessage message: String?) throws -> Never {
        if let message {
            throw CleanExit.message(message)
        } else {
            throw ExitCode.failure
        }
    }
}

protocol CommandCallback {
    func isInteractive() -> Bool
    func getSpotifyClientId() throws -> String
    func getSpotifyClientSecret() throws -> String
    func getAppRedirectUrl() throws -> URL?
    func getSpotifyRedirectUri(for redirectUri: URL?) throws -> URL?
    func exit(withMessage message: String?) throws -> Never
}
