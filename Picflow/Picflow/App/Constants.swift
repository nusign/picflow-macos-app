struct Constants {
    // MARK: - Development Test Credentials
    static let devToken = "eyJhbGciOiJSUzI1NiIsImNhdCI6ImNsX0I3ZDRQRDIyMkFBQSIsImtpZCI6Imluc18yYk9yRTdqMjEzdE9hSW5FQUlSSEVZbWtRMXEiLCJ0eXAiOiJKV1QifQ.eyJhenAiOiJodHRwczovL2Rldi5waWNmbG93LmNvbSIsImV4cCI6MTc4NzQ5NDIwOSwiaWF0IjoxNzYxNTc0MjA5LCJpc3MiOiJodHRwczovL3JlbGF4aW5nLXNhdHlyLTU1LmNsZXJrLmFjY291bnRzLmRldiIsImp0aSI6IjgxZmIwY2ZmYmEwMTdmNDllNDVkIiwibmJmIjoxNzYxNTc0MjA0LCJzdWIiOiJ1c2VyXzJlcEFtYkhzaDl6a0RZV0tRWnRPU3N5Qm9pSCJ9.WX1hvl6MU72bExrDUDQ305UF2uSB21DdFx_I3GnpStZSedo9LfPFEcWn3lM1sQmE6074yIFzq24HT9EeQ5FLkZaKfQvWs1jV5Rw3Rr0uOCigdXvKv5zTotPjoAtFxhDk0urxDnXCjZea_m6M_Z1Heg8aeSfDlDzEg6Ki7duPccOQeft4CnjDqE8mpfR7asoocIUiJhLECok3gbprQYKuB-m7UtASS7eeluzZ4T1IJRf1FIckiR_5WRDKg68tWJCETBDyTOPK5n15QICudOuDZQS1v28RoBYPB8oUycgG1jyyHxvjcrx5bWr7y-5TkzzCVtHSzs6D6WCEBTb52714Xg"
    static let devTenantId = "tnt_YXPF8Za9bFRvpoxh"
    
    // MARK: - Production Test Credentials
    static let prodToken = "eyJhbGciOiJSUzI1NiIsImNhdCI6ImNsX0I3ZDRQRDIyMkFBQSIsImtpZCI6Imluc18yZGQ3UTNuNTJ2dUZNbWpLa0k5Zm1DWHd5V1AiLCJ0eXAiOiJKV1QifQ.eyJhenAiOiJodHRwczovL3BpY2Zsb3cuY29tIiwiZXhwIjoyMDIwNzYyMTg3LCJpYXQiOjE3NjE1NjIxNzcsImlzcyI6Imh0dHBzOi8vY2xlcmsucGljZmxvdy5jb20iLCJqdGkiOiJjZmUyMWY2NmFlOTJhMGY2YjQwYyIsIm5iZiI6MTc2MTU2MjE3Miwic3ViIjoidXNlcl8yZHVEUjRndmliWVU5dWdGdndKZTJXNUFOeVYifQ.SSwVtySzBI6rrKVkXKsTerFkMty7UKGDYl8lYVN3KDJ9Op6bZ6KkHnSj3gC0nSyK6tOwXt4PN_nmGg1jYfS1XUlu5wb5rijGUxm4eamgnVvdjDl0cyxOI4YqCWpqNrv5l0mLKcBEL8bgIbR5gY_yXFMOz7QybkXxbh535OlTCiaFEMdeKgcJtTQ2wYPTE0-doRjj141rcY9jeM-i4VGoT3zMn8IWfOD_op6yAymAgnAMyrCF3rVa5vyjb3h5N5ycj_cb_xZVA06V96-r9qfVqhQ6dnMoOeQeT76-XLB_TWFwvG5KYgZ11_KwzHJVOliiUONZVh-wXhbP_QxgvI0T_w"
    static let prodTenantId = "tnt_KloxjZnrPJovBfu3"
    
    // MARK: - Environment-Aware Accessors
    static var hardcodedToken: String {
        switch EnvironmentManager.shared.current {
        case .development:
            return devToken
        case .production:
            return prodToken
        }
    }
    
    static var tenantId: String {
        switch EnvironmentManager.shared.current {
        case .development:
            return devTenantId
        case .production:
            return prodTenantId
        }
    }
    
    // MARK: - Other
    static let sentryDSN = "https://8471a574e3139b4f2c0fc39059ab39f3@o1075862.ingest.us.sentry.io/4510248420048896"
}
