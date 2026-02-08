import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authState: AuthState
    @State private var isAuthPresented = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("我的")
                .font(.headline)

            if authState.isLoggedIn, let user = authState.currentUser {
                Text("手机号：\(user.phone)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("退出登录") {
                    authState.signOut()
                }
                .buttonStyle(.bordered)
            } else {
                Text("登录后完善个人信息")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("登录 / 注册") {
                    isAuthPresented = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isAuthPresented) {
            AuthView()
                .environmentObject(authState)
        }
    }
}
