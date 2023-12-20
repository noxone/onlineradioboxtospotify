//
//  File.swift
//
//
//  Created by Olaf Neumann on 11.12.23.
//

import Foundation
import Logging

fileprivate let logger = Logger(label: "TrackCache")

actor TrackCache {
    typealias ID = String
    typealias Cache = [ID:CacheEntry]
    
    private static func loadOrCreateCache(fromUrl cacheLocation: URL) -> Cache {
        if let data = try? Data(contentsOf: cacheLocation),
           let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            return cache
        }
        
        return Cache()
    }
    
    private let cacheLocation: URL
    private var cache: Cache
    
    init(withLocation cacheLocation: URL) {
        self.cacheLocation = cacheLocation
        self.cache = TrackCache.loadOrCreateCache(fromUrl: cacheLocation)
    }
    
    func storeCache() throws {
        let data = try JSONEncoder().encode(cache)
        try data.write(to: cacheLocation)
    }
    
    var count: Int {
        cache.count
    }
    
    func updateEntry(withId id: ID, addDisplayName displayName: String? = nil, playingTime: Date? = nil, setTitle title: String? = nil, setArtist artist: String? = nil, setSpotifyUri spotifyUri: String? = nil, setSpotifyTitle spotifyTitle: String? = nil, setSpotifyArtist spotifyArtist: String? = nil, didSpotifyCheck: Bool = false) {
        let oldEntry = getEntry(forId: id)
        var names = Array(oldEntry?.orbDisplayNames ?? [])
        if let displayName {
            names.append(displayName)
        }
        var lastPlaytime = oldEntry?.lastPlaytime
        if let playingTime, lastPlaytime == nil || playingTime > lastPlaytime! {
            lastPlaytime = playingTime
        }
        let newEntry = CacheEntry(
            orbId: id,
            orbDisplayNames: Set(names),
            lastPlaytime: lastPlaytime,
            title: title ?? oldEntry?.title,
            artist: artist ?? oldEntry?.artist,
            spotifyLastCheck: didSpotifyCheck ? Date() : oldEntry?.spotifyLastCheck,
            spotifyUri: spotifyUri ?? oldEntry?.spotifyUri,
            spotifyTitle: spotifyTitle ?? oldEntry?.spotifyTitle,
            spotifyArtist: spotifyArtist ?? oldEntry?.spotifyArtist
        )
        setEntry(newEntry, forID: id)
    }
    
    private func setEntry(_ entry: CacheEntry, forID id: ID) {
        cache[id] = entry
    }
    
    func getEntry(forId id: ID) -> CacheEntry? {
        return cache[id]
    }
    
    var entriesWithoutTrackInfo: [CacheEntry] {
        cache.values.filter { $0.title == nil || $0.artist == nil }
    }
    
    var entriesWithoutSpotifyInfo: [CacheEntry] {
        cache.values.filter { $0.spotifyUri == nil }
    }
    
    func getSpotifyUri(forId id: ID) -> String? {
        return cache[id]?.spotifyUri
    }
}

struct CacheEntry : Codable {
    let orbId: String
    let orbDisplayNames: Set<String>
    let lastPlaytime: Date?
    let title: String?
    let artist: String?
    let spotifyLastCheck: Date?
    let spotifyUri: String?
    let spotifyTitle: String?
    let spotifyArtist: String?
}
