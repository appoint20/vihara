import Foundation
import CryptoKit
import Security

/// Where the session and the local email records live.
protocol CredentialStore: Sendable {
    func currentAccount() async -> UserAccount?
    func account(for id: Identifier<UserAccount>) async -> UserAccount?
    func save(_ account: UserAccount) async
    func clear() async

    func emailRecord(for email: String) async -> EmailRecord?
    func saveEmailRecord(_ record: EmailRecord) async
}

/// The Keychain.
///
/// `UserDefaults` would have been three lines, and would have written password hashes
/// and email addresses into a plist that any backup reads in the clear. The Keychain
/// is the right place for this even while the accounts are local-only, because the
/// day they stop being local-only is not the day anyone wants to be migrating storage.
///
/// `kSecAttrAccessibleAfterFirstUnlock`: the app restores its session on launch,
/// including a background launch, so the item has to be readable without the device
/// having been unlocked since boot — but never off-device, hence no iCloud sync.
actor KeychainCredentialStore: CredentialStore {
    private let service: String

    init(service: String = "com.vihara.app.credentials") {
        self.service = service
    }

    // MARK: - Session

    func currentAccount() async -> UserAccount? {
        decode(AccountRecord.self, for: Self.sessionKey)?.domain
    }

    func account(for id: Identifier<UserAccount>) async -> UserAccount? {
        decode(AccountRecord.self, for: Self.accountKey(id))?.domain
    }

    func save(_ account: UserAccount) async {
        let record = AccountRecord(account)
        encode(record, for: Self.sessionKey)
        // Also kept under its own id, so a returning Apple user gets the name they
        // gave the first time — Apple never sends it twice.
        encode(record, for: Self.accountKey(account.id))
    }

    func clear() async {
        delete(Self.sessionKey)
    }

    // MARK: - Email records

    func emailRecord(for email: String) async -> EmailRecord? {
        decode(EmailRecord.self, for: Self.emailKey(email))
    }

    func saveEmailRecord(_ record: EmailRecord) async {
        encode(record, for: Self.emailKey(record.email))
    }

    // MARK: - Keys

    private static let sessionKey = "session"
    private static func accountKey(_ id: Identifier<UserAccount>) -> String { "account:\(id.rawValue)" }
    private static func emailKey(_ email: String) -> String { "email:\(email.lowercased())" }

    // MARK: - Keychain plumbing

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    private func encode<Value: Encodable>(_ value: Value, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        var attributes = query(key)
        SecItemDelete(attributes as CFDictionary)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, for key: String) -> Value? {
        var attributes = query(key)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(attributes as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func delete(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }

    /// The stored shape. ADR-003 again: ``UserAccount`` is not `Codable`.
    private struct AccountRecord: Codable {
        let id: String
        let displayName: String
        let email: String?
        let provider: String

        init(_ account: UserAccount) {
            id = account.id.rawValue
            displayName = account.displayName
            email = account.email
            provider = account.provider.rawValue
        }

        var domain: UserAccount? {
            guard let provider = UserAccount.Provider(rawValue: provider) else { return nil }
            return UserAccount(id: Identifier(id),
                               displayName: displayName,
                               email: email,
                               provider: provider)
        }
    }
}

/// Hashing, in one place.
enum CryptoHash {
    static func sha256(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// URL-safe base64 of a SHA-256 digest — the shape PKCE's `S256` challenge wants.
    static func pkceChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Credentials held in memory, for tests and previews.
actor InMemoryCredentialStore: CredentialStore {
    private var session: UserAccount?
    private var accounts: [String: UserAccount] = [:]
    private var emails: [String: EmailRecord] = [:]

    init(session: UserAccount? = nil) {
        self.session = session
    }

    func currentAccount() async -> UserAccount? { session }
    func account(for id: Identifier<UserAccount>) async -> UserAccount? { accounts[id.rawValue] }

    func save(_ account: UserAccount) async {
        session = account
        accounts[account.id.rawValue] = account
    }

    func clear() async { session = nil }

    func emailRecord(for email: String) async -> EmailRecord? { emails[email.lowercased()] }
    func saveEmailRecord(_ record: EmailRecord) async { emails[record.email.lowercased()] = record }
}
