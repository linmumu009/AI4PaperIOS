import Foundation

enum AuthError: Error, Equatable {
    case invalidPhone
    case invalidCode
    case cooldown(remainingSeconds: Int)
    case codeExpired
    case codeMismatch
    case tooManyAttempts
    case storageFailure
    case unknown
}

struct AuthCodeDelivery: Equatable {
    let cooldownSeconds: Int
    let simulatedCode: String?
}

protocol AuthServiceProtocol {
    func loadSession() -> User?
    func requestCode(phone: String) -> Result<AuthCodeDelivery, AuthError>
    func verifyCode(phone: String, code: String) -> Result<User, AuthError>
    func signOut()
}

final class LocalAuthService: AuthServiceProtocol {
    private struct CodeRecord {
        var code: String
        var expiresAt: Date
        var lastRequestAt: Date
        var failedAttempts: Int
    }

    private let keychain = KeychainStore()
    private var records: [String: CodeRecord] = [:]
    private let cooldownSeconds = 60
    private let codeTTLSeconds = 5 * 60
    private let maxFailedAttempts = 5

    private enum KeychainKey {
        static let token = "auth.session.token"
        static let user = "auth.session.user"
    }

    func loadSession() -> User? {
        guard
            let userData = keychain.read(key: KeychainKey.user),
            let user = try? JSONDecoder().decode(User.self, from: userData)
        else {
            return nil
        }
        return user
    }

    func requestCode(phone: String) -> Result<AuthCodeDelivery, AuthError> {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidPhone(trimmed) else { return .failure(.invalidPhone) }
        let now = Date()
        if let record = records[trimmed] {
            let elapsed = now.timeIntervalSince(record.lastRequestAt)
            if elapsed < Double(cooldownSeconds) {
                let remaining = max(1, cooldownSeconds - Int(elapsed))
                return .failure(.cooldown(remainingSeconds: remaining))
            }
        }

        let code = String(format: "%06d", Int.random(in: 0...999_999))
        let record = CodeRecord(
            code: code,
            expiresAt: now.addingTimeInterval(Double(codeTTLSeconds)),
            lastRequestAt: now,
            failedAttempts: 0
        )
        records[trimmed] = record

        let delivery = AuthCodeDelivery(cooldownSeconds: cooldownSeconds, simulatedCode: code)
        return .success(delivery)
    }

    func verifyCode(phone: String, code: String) -> Result<User, AuthError> {
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidPhone(trimmedPhone) else { return .failure(.invalidPhone) }
        guard isValidCode(trimmedCode) else { return .failure(.invalidCode) }
        guard var record = records[trimmedPhone] else { return .failure(.codeExpired) }
        let now = Date()
        guard now <= record.expiresAt else {
            records.removeValue(forKey: trimmedPhone)
            return .failure(.codeExpired)
        }
        guard record.failedAttempts < maxFailedAttempts else {
            return .failure(.tooManyAttempts)
        }
        guard record.code == trimmedCode else {
            record.failedAttempts += 1
            records[trimmedPhone] = record
            return .failure(record.failedAttempts >= maxFailedAttempts ? .tooManyAttempts : .codeMismatch)
        }

        records.removeValue(forKey: trimmedPhone)
        let user = User(phone: trimmedPhone)
        let token = SessionToken()
        guard
            let userData = try? JSONEncoder().encode(user),
            let tokenData = try? JSONEncoder().encode(token),
            keychain.save(key: KeychainKey.user, data: userData),
            keychain.save(key: KeychainKey.token, data: tokenData)
        else {
            return .failure(.storageFailure)
        }
        return .success(user)
    }

    func signOut() {
        keychain.delete(key: KeychainKey.user)
        keychain.delete(key: KeychainKey.token)
    }

    private func isValidPhone(_ phone: String) -> Bool {
        let digits = phone.filter(\.isNumber)
        return digits.count == 11
    }

    private func isValidCode(_ code: String) -> Bool {
        let digits = code.filter(\.isNumber)
        return digits.count == 6
    }
}
