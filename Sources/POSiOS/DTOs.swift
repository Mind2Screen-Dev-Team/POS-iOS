import Foundation

public struct ProductDTO: Codable, Sendable {
    public let id: String
    public let name: String
    public let price: Int
    public let stock: Int
}

public struct CartItemDTO: Codable, Sendable {
    public let productID: String
    public let quantity: Int
}

public struct OrderDTO: Codable, Sendable {
    public let id: String
    public let items: [CartItemDTO]
    public let total: Int
    public let createdAt: Date
}