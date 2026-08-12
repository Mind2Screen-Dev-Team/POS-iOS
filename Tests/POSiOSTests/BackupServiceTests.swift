import XCTest
@testable import POSiOS

/// Client tiruan: ganti request/ack server, membiarkan tes isolasi logika
/// batch -> ack -> hapus tanpa jaringan.
private final class StubClient: APIClientProtocol {
    var ackResult: Result<BackupAckDTO, Error>?
    var restoreResult: Result<BackupRestoreDTO, Error>?
    var postedBodies: [BackupRequestDTO] = []
    var requestedPaths: [String] = []

    func request<T: Decodable>(path: String, method: String) async throws -> T {
        requestedPaths.append(path)
        if let restoreResult,
           T.self == BackupRestoreDTO.self {
            switch restoreResult {
            case .success(let value): return value as! T
            case .failure(let error): throw error
            }
        }
        throw APIClientError.httpError(statusCode: 500)
    }

    func request<T: Decodable, B: Encodable>(path: String, method: String, body: B) async throws -> T {
        guard let body = body as? BackupRequestDTO else {
            throw APIClientError.invalidResponse
        }
        postedBodies.append(body)
        switch ackResult! {
        case .success(let value): return value as! T
        case .failure(let error): throw error
        }
    }
}

final class BackupServiceTests: XCTestCase {
    private func isoDate(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func record(_ id: String, _ date: Date) -> LocalTransactionStore.Record {
        LocalTransactionStore.Record(id: id, transactedAt: date, payload: ["id": .string(id)])
    }

    // MARK: - UUID

    func testDeviceIdentityGeneratesValidUUID() {
        let id = DeviceIdentity.userID
        XCTAssertNotNil(UUID(uuidString: id))
    }

    // MARK: - Rentang tanggal

    func testDateRangeFormatYYYYMMDD() {
        let start = isoDate("2026-08-01T00:00:00Z")
        let end = isoDate("2026-08-31T23:59:59Z")
        guard let range = BackupDate.rangeString(start: start, end: end) else {
            return XCTFail("range harus valid")
        }
        XCTAssertEqual(range.start, "2026-08-01")
        XCTAssertEqual(range.end, "2026-08-31")
    }

    func testDateRangeRejectsEndBeforeStart() {
        let start = isoDate("2026-08-31T00:00:00Z")
        let end = isoDate("2026-08-01T00:00:00Z")
        XCTAssertNil(BackupDate.rangeString(start: start, end: end))
    }

    // MARK: - Batch <= 500

    func testBatchesSplitAt500() {
        let start = isoDate("2026-01-01T00:00:00Z")
        let records = (1...1200).map { record("t\($0)", start) }
        let store = LocalTransactionStore(records: records)
        let batches = store.batches()
        XCTAssertEqual(batches.count, 3)
        XCTAssertEqual(batches[0].count, 500)
        XCTAssertEqual(batches[1].count, 500)
        XCTAssertEqual(batches[2].count, 200)
        XCTAssertTrue(batches.allSatisfy { $0.count <= BackupBatch.maxTransactions })
    }

    // MARK: - Ack -> hapus per batch

    func testBackupDeletesBatchOnlyAfterAck() async {
        let start = isoDate("2026-01-01T00:00:00Z")
        let end = isoDate("2026-01-31T00:00:00Z")
        let records = (1...501).map { record("t\($0)", start) }
        let store = LocalTransactionStore(records: records)
        let client = StubClient()
        client.ackResult = .success(BackupAckDTO(status: "ok", backup_id: "b1", stored_count: 500))
        let service = BackupService(client: client, store: store, userID: "11111111-1111-1111-1111-111111111111")

        let summary = try? await service.backup(start: start, end: end)

        XCTAssertNotNil(summary)
        XCTAssertEqual(store.all().count, 0, "semua batch ter-ack -> semua terhapus")
        XCTAssertEqual(client.postedBodies.count, 2, "501 transaksi -> 2 batch")
        XCTAssertTrue(client.postedBodies.allSatisfy { $0.transactions.count <= 500 })
        XCTAssertTrue(client.postedBodies.allSatisfy {
            $0.user_id == "11111111-1111-1111-1111-111111111111"
        })
    }

    func testBackupFailureKeepsDataIntact() async {
        let start = isoDate("2026-01-01T00:00:00Z")
        let end = isoDate("2026-01-31T00:00:00Z")
        let records = (1...501).map { record("t\($0)", start) }
        let store = LocalTransactionStore(records: records)
        let client = StubClient()
        client.ackResult = .failure(APIClientError.httpError(statusCode: 500))
        let service = BackupService(client: client, store: store, userID: "11111111-1111-1111-1111-111111111111")

        do {
            _ = try await service.backup(start: start, end: end)
            XCTFail("harus throw")
        } catch {
            XCTAssertEqual(store.all().count, 501, "gagal server -> data tetap utuh")
        }
    }

    // MARK: - Ukuran storage

    func testLocalStorageSize() {
        let start = isoDate("2026-01-01T00:00:00Z")
        let store = LocalTransactionStore(records: [
            record("a", start),
            record("b", start),
        ])
        XCTAssertGreaterThan(store.localSizeBytes, 0)
    }

    // MARK: - Restore parse response

    func testRestoreParsesResponse() async {
        let start = isoDate("2026-01-01T00:00:00Z")
        let end = isoDate("2026-01-31T00:00:00Z")
        let client = StubClient()
        let tx = BackupTransactionDTO(
            id: "t1",
            user_id: "11111111-1111-1111-1111-111111111111",
            transacted_at: "2026-01-05T10:00:00Z",
            payload: ["nama": .string("Kopi"), "harga": .number(15000)]
        )
        client.restoreResult = .success(BackupRestoreDTO(transactions: [tx]))
        let service = BackupService(
            client: client,
            store: LocalTransactionStore(),
            userID: "11111111-1111-1111-1111-111111111111"
        )

        let restored = try? await service.restore(
            userID: "11111111-1111-1111-1111-111111111111",
            start: start,
            end: end
        )

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.count, 1)
        XCTAssertEqual(restored?.first?.id, "t1")
        XCTAssertEqual(restored?.first?.payload?["nama"], .string("Kopi"))
        XCTAssertTrue(client.requestedPaths.first?.contains("user_id=") == true)
        XCTAssertTrue(client.requestedPaths.first?.contains("start_date=2026-01-01") == true)
        XCTAssertTrue(client.requestedPaths.first?.contains("end_date=2026-01-31") == true)
    }

    // MARK: - Decode JSON per CONTRACT-301

    func testDecodeBackupAckResponse() throws {
        let json = """
        {"status": "ok", "backup_id": "b-123", "stored_count": 3}
        """.data(using: .utf8)!
        let ack = try JSONDecoder().decode(BackupAckDTO.self, from: json)
        XCTAssertEqual(ack.status, "ok")
        XCTAssertEqual(ack.stored_count, 3)
    }

    func testDecodeRestoreResponse() throws {
        let json = """
        {
          "transactions": [
            {
              "id": "t1",
              "user_id": "11111111-1111-1111-1111-111111111111",
              "transacted_at": "2026-01-05T10:00:00Z",
              "payload": {"nama": "Kopi", "qty": 2}
            }
          ]
        }
        """.data(using: .utf8)!
        let restore = try JSONDecoder().decode(BackupRestoreDTO.self, from: json)
        XCTAssertEqual(restore.transactions.count, 1)
        XCTAssertEqual(restore.transactions[0].payload?["nama"], .string("Kopi"))
        XCTAssertEqual(restore.transactions[0].payload?["qty"], .number(2))
    }
}
