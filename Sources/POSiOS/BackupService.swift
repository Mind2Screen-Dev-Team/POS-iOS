import Foundation

/// Formatter tanggal rentang backup (YYYY-MM-DD, ISO 8601).
public enum BackupDate {
    public static func dateString(_ date: Date) -> String {
        BackupDate.formatter.string(from: date)
    }

    /// Format rentang `start_date`..`end_date`. Tanggal dikunci ke tengah hari
    /// UTC agar aman dari pergeseran zona waktu. Invalid pair -> nil.
    public static func rangeString(start: Date, end: Date) -> (start: String, end: String)? {
        let s = BackupDate.dateString(start)
        let e = BackupDate.dateString(end)
        guard let startDay = BackupDate.parse(s),
              let endDay = BackupDate.parse(e),
              startDay <= endDay else {
            return nil
        }
        return (s, e)
    }

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parse(_ string: String) -> Date? {
        formatter.date(from: string)
    }
}

/// Penyimpanan lokal transaksi (stand-in DTO; sumber asli diganti UI/DB layer
/// sesuai pola app). Menyimpan payload JSONB + tanggal transaksi.
public final class LocalTransactionStore {
    public struct Record: Codable, Sendable {
        public let id: String
        public let transactedAt: Date
        public let payload: [String: JSONValue]?
    }

    private var records: [Record]
    private let queue = DispatchQueue(label: "pos.ios.transaction.store")

    public init(records: [Record] = []) {
        self.records = records
    }

    /// Total ukuran payload lokal dalam byte (dasar ukuran storage halaman backup).
    public var localSizeBytes: Int {
        queue.sync {
            records.reduce(0) { acc, r in
                guard let payload = r.payload else { return acc }
                return acc + ((try? JSONEncoder().encode(payload).count) ?? 0)
            }
        }
    }

    /// Kirim per-batch max 500: potong records jadi batch-batch.
    public func batches() -> [[Record]] {
        queue.sync {
            stride(from: 0, to: records.count, by: BackupBatch.maxTransactions)
                .map { Array(records[$0..<min($0 + BackupBatch.maxTransactions, records.count)]) }
        }
    }

    /// Hapus batch dari storage. Dipanggil hanya setelah ack server (data
    /// utuh di device sampai backup berhasil).
    public func delete(ids: Set<String>) {
        queue.sync {
            records.removeAll { ids.contains($0.id) }
        }
    }

    public func all() -> [Record] {
        queue.sync { records }
    }
}

/// Error layer backup. `noConnection`/`server` dipetakan UI ke screen error
/// existing (No connection / Error state).
public enum BackupError: Error, Sendable {
    case invalidDateRange
    case emptyBatch
    case noConnection
    case server(statusCode: Int)
    case invalidResponse
}

/// BackupService: kirim per-batch max 500, hapus batch hanya setelah ack
/// server, restore via GET, hitung storage local.
public final class BackupService {
    private let client: APIClientProtocol
    private let store: LocalTransactionStore
    private let userID: String
    public let batchLimit = BackupBatch.maxTransactions

    public init(
        client: APIClientProtocol,
        store: LocalTransactionStore,
        userID: String = DeviceIdentity.userID
    ) {
        self.client = client
        self.store = store
        self.userID = userID
    }

    /// Ukuran storage yang dipakai app, dihitung dari data lokal (bukan total device).
    public var localStorageSizeBytes: Int { store.localSizeBytes }

    /// Backup rentang `start`..`end`. Batch dihapus dari storage lokal hanya
    /// setelah ack 200 server. Bila gagal, data tetap utuh dan error dilaporkan.
    public func backup(start: Date, end: Date) async throws -> BackupSummary {
        guard let range = BackupDate.rangeString(start: start, end: end) else {
            throw BackupError.invalidDateRange
        }
        let batches = store.batches()
        guard !batches.isEmpty else {
            throw BackupError.emptyBatch
        }

        var totalStored = 0
        var backupIDs: [String] = []
        for batch in batches {
            let transactions = batch.map { record in
                BackupTransactionDTO(
                    id: record.id,
                    user_id: userID,
                    transacted_at: ISO8601DateFormatter().string(from: record.transactedAt),
                    payload: record.payload
                )
            }
            let body = BackupRequestDTO(
                user_id: userID,
                start_date: range.start,
                end_date: range.end,
                transactions: transactions
            )
            let ack: BackupAckDTO = try await client.request(
                path: "/backup",
                method: "POST",
                body: body
            )
            store.delete(ids: Set(batch.map(\.id)))
            totalStored += ack.stored_count
            backupIDs.append(ack.backup_id)
        }
        return BackupSummary(storedCount: totalStored, backupIDs: backupIDs)
    }

    /// Restore transaksi pada rentang untuk `user_id`. UUID manual diisi
    /// pengguna pada device baru. GET idempoten — data server tidak dihapus.
    public func restore(userID: String, start: Date, end: Date) async throws -> [BackupTransactionDTO] {
        guard let range = BackupDate.rangeString(start: start, end: end) else {
            throw BackupError.invalidDateRange
        }
        guard let escaped = userID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let s = range.start.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let e = range.end.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw BackupError.invalidResponse
        }
        let path = "/backup?user_id=\(escaped)&start_date=\(s)&end_date=\(e)"
        let response: BackupRestoreDTO = try await client.request(path: path, method: "GET")
        return response.transactions
    }
}

/// Ringkasan hasil backup (untuk UI / log).
public struct BackupSummary: Sendable, Equatable {
    public let storedCount: Int
    public let backupIDs: [String]
}
