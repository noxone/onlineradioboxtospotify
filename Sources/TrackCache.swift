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
    
    private static let cacheLocation = Files.url(forFilename: "trackcache.json")

    private static func loadOrCreateCache() -> Cache {
        if let data = try? Data(contentsOf: TrackCache.cacheLocation),
           let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            return cache
        }
        
        return Cache()
    }
    
    static let shared = TrackCache(withCache: loadOrCreateCache())
    
    
    private var cache: Cache
    
    private init(withCache cache: Cache) {
        self.cache = cache
    }
    
    func storeCache() throws {
        let data = try JSONEncoder().encode(cache)
        try data.write(to: TrackCache.cacheLocation)
    }
    
    var count: Int {
        cache.count
    }
    
    func updateEntry(withId id: ID, addDisplayName displayName: String? = nil, setTitle title: String? = nil, setArtist artist: String? = nil, setSpotifyUri spotifyUri: String? = nil, didSpotifyCheck: Bool = false) {
        let oldEntry = getEntry(forId: id)
        var names = Array(oldEntry?.orbDisplayNames ?? [])
        if let displayName {
            names.append(displayName)
        }
        let newEntry = CacheEntry(
            orbId: id,
            orbDisplayNames: Set(names),
            lastPlaytime: nil,
            title: title ?? oldEntry?.title,
            artist: artist ?? oldEntry?.artist,
            lastCheck: didSpotifyCheck ? Date() : oldEntry?.lastCheck,
            spotifyUri: spotifyUri ?? oldEntry?.spotifyUri
        )
        setEntry(newEntry, forID: id)
    }
    
    private func setEntry(_ entry: CacheEntry, forID id: ID) {
        cache[id] = entry
    }
    
    func getEntry(forId id: ID) -> CacheEntry? {
        return cache[id]
    }
}

struct CacheEntry : Codable {
    let orbId: String
    let orbDisplayNames: Set<String>
    let lastPlaytime: Date?
    let title: String?
    let artist: String?
    let lastCheck: Date?
    let spotifyUri: String?
}
