import AWSLambdaRuntime

struct Input: Codable {
    let station: String
}

struct Output: Codable {
    let result: String
}

Lambda.run { (context, input: Input, callback: @escaping (Result<Output, Error>) -> Void) in
    let output = Output(result: "Station: \(input.station)")
    
    callback(.success(output))
}
