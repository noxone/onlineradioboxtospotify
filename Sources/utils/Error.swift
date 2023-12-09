//
//  File.swift
//  
//
//  Created by Olaf Neumann on 09.12.23.
//

import Foundation

enum ORBTSError: LocalizedError {
    case numberOfDaysTooLow(number: Int)
    case unableToLoadPage
    case invalidResponseType
    case downloadFailed
    case unableToBuildUrl(station: String)
}
