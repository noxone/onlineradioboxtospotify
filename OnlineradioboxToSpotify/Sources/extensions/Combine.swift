//
//  File.swift
//  
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation
import Combine

// https://medium.com/geekculture/from-combine-to-async-await-c08bf1d15b77
extension AnyPublisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = first()
                .sink { result in
                    switch result {
                    case .finished:
                        break
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                } receiveValue: { value in
                    continuation.resume(with: .success(value))
                }
        }
    }
}

func runAndWait(_ code: @escaping () async -> Void) {
    let group = DispatchGroup()
    group.enter()
    
    Task {
        await code()
        group.leave()
    }
    
    group.wait()
}
