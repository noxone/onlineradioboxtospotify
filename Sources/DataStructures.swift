//
//  File.swift
//  
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation

struct Input: Codable {
    let station: String
}

struct Output: Codable {
    let result: String
    let items: Int
}

