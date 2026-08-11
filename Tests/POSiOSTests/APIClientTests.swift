import XCTest
@testable import POSiOS

final class APIClientTests: XCTestCase {
    func testBaseURLDefault() {
        XCTAssertNotNil(EnvironmentConfig.baseURL)
    }

    func testDecoderCanDecodeProduct() throws {
        let json = """
        {"id": "p1", "name": "Kopi", "price": 15000, "stock": 10}
        """.data(using: .utf8)!
        let product = try JSONDecoder().decode(ProductDTO.self, from: json)
        XCTAssertEqual(product.name, "Kopi")
        XCTAssertEqual(product.price, 15000)
    }
}