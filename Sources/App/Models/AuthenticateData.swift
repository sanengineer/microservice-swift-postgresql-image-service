import Vapor

public struct AuthenticateData: Content {
    let token: String
}