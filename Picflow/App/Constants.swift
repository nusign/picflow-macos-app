struct Constants {
    // MARK: - App Identity
    static let appURLScheme = "picflow-macos"
    static let bundleIdentifier = "com.picflow.macos"
    
    // MARK: - OAuth
    static let oauthRedirectURI = "\(appURLScheme)://auth/callback"
    static let oauthScopes = "openid profile email"
    
    // MARK: - Services
    static let sentryDSN = "https://8471a574e3139b4f2c0fc39059ab39f3@o1075862.ingest.us.sentry.io/4510248420048896"
}