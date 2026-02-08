import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authState: AuthState
    @Environment(\.dismiss) private var dismiss

    @State private var phone: String = ""
    @State private var code: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("手机号", text: $phone)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .onChange(of: phone) { _ in authState.clearError() }
                }

                Section {
                    HStack {
                        TextField("验证码", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: code) { _ in authState.clearError() }
                        Spacer()
                        Button(action: requestCode) {
                            Text(codeButtonTitle)
                        }
                        .disabled(!canRequestCode)
                    }
                }

                Section {
                    Button("登录 / 注册", action: verifyCode)
                        .disabled(!canVerify)
                }

                if let message = authState.authErrorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("手机号登录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: authState.isLoggedIn) { newValue in
                if newValue { dismiss() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .authSimulatedCodeGenerated)) { notification in
                #if DEBUG
                if let code = notification.object as? String {
                    self.code = code
                }
                #endif
            }
        }
    }

    private var canRequestCode: Bool {
        authState.cooldownRemaining == 0 && isValidPhone
    }

    private var canVerify: Bool {
        isValidPhone && isValidCode
    }

    private var isValidPhone: Bool {
        phone.filter(\.isNumber).count == 11
    }

    private var isValidCode: Bool {
        code.filter(\.isNumber).count == 6
    }

    private var codeButtonTitle: String {
        authState.cooldownRemaining > 0 ? "重新发送(\(authState.cooldownRemaining)s)" : "获取验证码"
    }

    private func requestCode() {
        authState.requestCode(phone: phone)
    }

    private func verifyCode() {
        authState.verifyCode(phone: phone, code: code)
    }
}
