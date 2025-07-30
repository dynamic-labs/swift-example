import DynamicSwiftSDK
import Foundation
import SwiftUI

struct AuthenticatedView: View {
    let client: DynamicClient
    let onLogout: () -> Void

    @State private var tokenCopied = false
    @State private var showWalletView = false
    @State private var verifiedCredentials: [JwtVerifiedCredential] = []
    @State private var isCreatingWallet = false

    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerView
                tokenView
                verifiedCredentialsView
                createWalletButton
                logoutButton
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()  // Optional: remove if you want to respect safe areas
        .task {
            updateCredentials()
        }
    }

    private func updateCredentials() {
        verifiedCredentials = client.user?.verifiedCredentials ?? []
    }
}

// MARK: - Subviews
extension AuthenticatedView {
    @ViewBuilder
    fileprivate var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("👋 Logged in as \(client.user?.email ?? client.user?.phoneNumber ?? "Unknown")")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("Project: \(client.projectSettings?.general.displayName ?? "None")")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    @ViewBuilder
    fileprivate var tokenView: some View {
        if let token = client.token {
            Button(action: {
                UIPasteboard.general.string = token
                tokenCopied = true

                // Reset the copied state after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    tokenCopied = false
                }
            }) {
                HStack {
                    Text(tokenCopied ? "Token Copied! ✓" : "Token: \(String(token.prefix(22)))...")
                        .font(.footnote)
                        .foregroundColor(tokenCopied ? .blue : .secondary)
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.blue)
                        .font(.footnote)
                }
                .padding(.vertical, 8)
                // Removed card background and corner radius
            }
            .buttonStyle(.plain)
            .scaleEffect(tokenCopied ? 1.05 : 1)
            .animation(.easeInOut, value: tokenCopied)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    fileprivate var verifiedCredentialsView: some View {
        if !verifiedCredentials.isEmpty {
            VerifiedCredentialsView(verifiedCredentials: verifiedCredentials, client: client)
                .padding(.horizontal)
            // Removed card background and corner radius
        }
    }

    fileprivate var createWalletButton: some View {
        Button(action: {
            isCreatingWallet = true
            Task {
                if (try? await createWalletAccount(client: client)) != nil {
                    await MainActor.run {
                        updateCredentials()
                    }
                }
                await MainActor.run {
                    isCreatingWallet = false
                }
            }
        }) {
            HStack {
                Text(isCreatingWallet ? "Creating Wallet..." : "Create Wallet")
                    .fontWeight(.semibold)
                if isCreatingWallet {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .top, endPoint: .bottom)
            )
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isCreatingWallet)
        .padding(.horizontal)
    }

    fileprivate var logoutButton: some View {
        Button(action: {
            Task {
                try? await logout(client: client)
                onLogout()
            }
        }) {
            Text("Logout")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                        startPoint: .top, endPoint: .bottom)
                )
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
