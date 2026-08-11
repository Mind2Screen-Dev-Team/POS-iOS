import Foundation

public struct EnvironmentConfig {
    public static let baseURL: URL = {
        if let customURL = ProcessInfo.processInfo.environment["POS_API_BASE_URL"],
           let url = URL(string: customURL) {
            return url
        }
        return URL(string: "https://api.pos.example.com/v1")!
    }()

    public static let timeoutInterval: TimeInterval = 30.0
}
