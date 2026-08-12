import Foundation

/// Batas maksimum transaksi per request batch (CONTRACT-301 / BL-BE-001).
public enum BackupBatch {
    public static let maxTransactions = 500
}

/// Satu transaksi yang dikirim/diterima via endpoint backup (CONTRACT-301 `Transaction`).
public struct BackupTransactionDTO: Codable, Sendable, Equatable {
    public let id: String
    public let user_id: String
    public let transacted_at: String
    public let payload: [String: JSONValue]?

    public init(id: String, user_id: String, transacted_at: String, payload: [String: JSONValue]? = nil) {
        self.id = id
        self.user_id = user_id
        self.transacted_at = transacted_at
        self.payload = payload
    }
}

/// Payload JSONB transaksi asli (referensi produk, kategori, metode bayar).
public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "nilai JSON tidak dikenal")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
}

/// Body POST /api/v1/backup (CONTRACT-301 request).
public struct BackupRequestDTO: Codable, Sendable {
    public let user_id: String
    public let start_date: String
    public let end_date: String
    public let transactions: [BackupTransactionDTO]

    public init(user_id: String, start_date: String, end_date: String, transactions: [BackupTransactionDTO]) {
        self.user_id = user_id
        self.start_date = start_date
        self.end_date = end_date
        self.transactions = transactions
    }
}

/// Response POST /api/v1/backup — ack per batch (CONTRACT-301).
public struct BackupAckDTO: Codable, Sendable, Equatable {
    public let status: String
    public let backup_id: String
    public let stored_count: Int

    public init(status: String, backup_id: String, stored_count: Int) {
        self.status = status
        self.backup_id = backup_id
        self.stored_count = stored_count
    }
}

/// Response GET /api/v1/backup — restore (CONTRACT-301).
public struct BackupRestoreDTO: Codable, Sendable, Equatable {
    public let transactions: [BackupTransactionDTO]

    public init(transactions: [BackupTransactionDTO]) {
        self.transactions = transactions
    }
}
