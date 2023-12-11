//
//  File.swift
//  
//
//  Created by Olaf Neumann on 11.12.23.
//

import Foundation

class TrackCache : Codable {
    private static func loadOrCreateCache() -> TrackCache {
        if let url = URL(string: "./trackcache.json"),
           let data = try? Data(contentsOf: url),
           let cache = try? JSONDecoder().decode(TrackCache.self, from: data) {
            return cache
        }
        
        return TrackCache()
    }
    
    static let shared = loadOrCreateCache()
    
    private var dict = [String:String]()
    
    private init() {}
    
    
}
