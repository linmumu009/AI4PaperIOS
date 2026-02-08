import Foundation

@MainActor
final class AuthState: ObservableObject {
    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var currentUser: User?
    @Published var authErrorMessage: String?
    @Published var cooldownRemaining: Int = 0

    private let service: AuthServiceProtocol
    private var cooldownTimer: Timer?

    init(service: AuthServiceProtocol = LocalAuthService()) {
        self.service = service
        if let user = service.loadSession() {
            self.currentUser = user
            self.isLoggedIn = true
        }
    }

    func requestCode(phone: String) {
        clearError()
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidPhone(trimmed) else {
            authErrorMessage = "请输入有效的手机号"
            return
        }

        switch service.requestCode(phone: trimmed) {
        case .success(let delivery):
            startCooldown(seconds: delivery.cooldownSeconds)
            #if DEBUG
            if let simulatedCode = delivery.simulatedCode {
                authErrorMessage = "已发送验证码（本地模拟）"
                NotificationCenter.default.post(
                    name: .authSimulatedCodeGenerated,
                    object: simulatedCode
                )
            }
            #else
            authErrorMessage = "验证码已发送"
            #endif
        case .failure(let error):
            authErrorMessage = message(for: error)
        }
    }

    func verifyCode(phone: String, code: String) {
        clearError()
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidPhone(trimmedPhone) else {
            authErrorMessage = "请输入有效的手机号"
            return
        }
        guard isValidCode(trimmedCode) else {
            authErrorMessage = "请输入6位验证码"
            return
        }

        switch service.verifyCode(phone: trimmedPhone, code: trimmedCode) {
        case .success(let user):
            currentUser = user
            isLoggedIn = true
        case .failure(let error):
            authErrorMessage = message(for: error)
        }
    }

    func signOut() {
        service.signOut()
        currentUser = nil
        isLoggedIn = false
        clearError()
        stopCooldown()
    }

    func clearError() {
        authErrorMessage = nil
    }

    private func startCooldown(seconds: Int) {
        cooldownRemaining = max(0, seconds)
        cooldownTimer?.invalidate()
        guard cooldownRemaining > 0 else { return }
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if self.cooldownRemaining > 0 {
                self.cooldownRemaining -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func stopCooldown() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        cooldownRemaining = 0
    }

    private func isValidPhone(_ phone: String) -> Bool {
        let digits = phone.filter(\.isNumber)
        return digits.count == 11
    }

    private func isValidCode(_ code: String) -> Bool {
        let digits = code.filter(\.isNumber)
        return digits.count == 6
    }

    private func message(for error: AuthError) -> String {
        switch error {
        case .cooldown(let remaining):
            return "请求过于频繁，请\(remaining)秒后再试"
        case .codeExpired, .codeMismatch:
            return "验证码错误或已过期"
        case .tooManyAttempts:
            return "验证失败次数过多，请稍后再试"
        case .storageFailure:
            return "登录失败，请稍后重试"
        case .invalidPhone:
            return "请输入有效的手机号"
        case .invalidCode:
            return "请输入6位验证码"
        case .unknown:
            return "出现未知错误"
        }
    }
}

extension Notification.Name {
    static let authSimulatedCodeGenerated = Notification.Name("authSimulatedCodeGenerated")
}
