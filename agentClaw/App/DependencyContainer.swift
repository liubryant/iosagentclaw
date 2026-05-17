import Foundation

final class DependencyContainer {
    let preferences: AppPreferences
    let keychain: KeychainStore
    let httpClient: HTTPClient
    let gatewayClient: GatewayClient

    init(
        preferences: AppPreferences = AppPreferences(),
        keychain: KeychainStore = KeychainStore(),
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) {
        self.preferences = preferences
        self.keychain = keychain
        self.httpClient = httpClient
        self.gatewayClient = GatewayClient(
            preferences: preferences,
            keychain: keychain,
            httpClient: httpClient
        )
    }
}

