import Foundation

public protocol APIClientProtocol {
    func request<T: Decodable>(path: String, method: String) async throws -> T
    func request<T: Decodable, B: Encodable>(path: String, method: String, body: B) async throws -> T
}

public final class APIClient: APIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = EnvironmentConfig.timeoutInterval
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func request<T: Decodable>(path: String, method: String = "GET") async throws -> T {
        guard let url = URL(string: path, relativeTo: EnvironmentConfig.baseURL) else {
            throw APIClientError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIClientError.httpError(statusCode: http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }

    public func request<T: Decodable, B: Encodable>(path: String, method: String = "GET", body: B) async throws -> T {
        guard let url = URL(string: path, relativeTo: EnvironmentConfig.baseURL) else {
            throw APIClientError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIClientError.httpError(statusCode: http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }
}

public enum APIClientError: Error, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
}
