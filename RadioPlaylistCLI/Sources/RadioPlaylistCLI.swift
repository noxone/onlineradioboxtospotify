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
    @Option(name: .shortAndLong) var credentialsFilename: String = "credentials.json"
    @Option(name: .shortAndLong) var spotifyRedirectUri: String?
    
    @Flag(name: .shortAndLong) var readRedirectUriFromStdIn: Bool = false
    
    @Argument var spotifyClientId: String
    @Argument var spotifyClientSecret: String
    
    @Argument var radioStation: String
    @Argument var playlistName: String
    
    mutating func run() async throws {
        print("Hello, world!")
    }
    
    private func checkParameters() {
        // TODO
    }
    
}
