// The Swift Programming Language
// https://docs.swift.org/swift-book

import SpotifyWebAPI

public class RadioPlaylistLib {
    public init() {}
    
    public func doSomething() {
        print("x")
        print(SpotifyAPI(authorizationManager: AuthorizationCodeFlowManager(clientId: "", clientSecret: "")))
    }
    
    public func doSomethingNew(with spotifyApi: SpotifyAPI<AuthorizationCodeFlowManager>) {
        print("YY")
        print(spotifyApi)
    }
}
