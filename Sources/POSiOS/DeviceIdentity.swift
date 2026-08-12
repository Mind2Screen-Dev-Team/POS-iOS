import Foundation

/// Identitas anonim perangkat. Pertama kali app jalan: generate UUID,
/// simpan permanen, dipakai sebagai `user_id` semua request backup.
public enum DeviceIdentity {
    private static let defaultsKey = "pos.ios.deviceUUID"

    public static var userID: String {
        if let existing = UserDefaults.standard.string(forKey: defaultsKey),
           !existing.isEmpty,
           UUID(uuidString: existing) != nil {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: defaultsKey)
        return fresh
    }
}
