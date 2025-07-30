import DynamicSwiftSDK
import Foundation
import SwiftUI

enum AuthMode {
    case email
    case phone
}

struct UnauthenticatedView: View {
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme

    let client: DynamicClient
    @Binding var message: String

    @State private var selectedCountryCode = "1"
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var phoneCountryCode: String = ""
    @State private var verificationCode: String = ""
    @State private var otpVerification: OTPVerification?
    @State private var mode: AuthMode = .email
    @State private var isSendingOTP: Bool = false
    @State private var isVerifyingOTP: Bool = false

    public init(client: DynamicClient, message: Binding<String>) {
        self.client = client
        self._message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            titleSection
            inputSection
            otpSection
            divider
            socialLoginButtons
            footer
        }
        .padding()
        .background(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.vertical, 32)
    }

    private var titleSection: some View {
        Text("Log in or sign up")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.primary)
    }

    @ViewBuilder
    private var inputSection: some View {
        if mode == .email {
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.secondary)
                TextField("Enter your email", text: $email)
                    .textFieldStyle(.plain)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .foregroundColor(.primary)
            }
            .inputBoxStyle(colorScheme)
            .frame(maxWidth: .infinity)
        } else {
            HStack {
                Image(systemName: "phone")
                    .foregroundColor(.secondary)
                Picker("Code", selection: $selectedCountryCode) {
                    Text("+1").tag("1")
                }
                .pickerStyle(.menu)
                .frame(width: 60)
                TextField("Enter your phone number", text: $phoneNumber)
                    .textFieldStyle(.plain)
                    .keyboardType(.phonePad)
                    .foregroundColor(.primary)
            }
            .inputBoxStyle(colorScheme)
        }

        Button(action: sendOTP) {
            if isSendingOTP {
                ProgressView().tint(.white)
            } else {
                Text("Continue")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .cornerRadius(8)
        .padding(.horizontal)  // Add this to match input's padding
        .disabled(
            (mode == .email && email.isEmpty) || (mode == .phone && phoneNumber.isEmpty)
                || isSendingOTP
        )

        // Fixed: Wrap the concatenated text in HStack and apply gesture to the container
        HStack {
            Text(mode == .email ? "Prefer phone number signup? " : "Prefer email signup? ")
                .font(.footnote)
                .foregroundColor(.secondary)
                + Text(mode == .email ? "Use phone" : "Use email")
                .font(.footnote)
                .foregroundColor(.blue)
        }
        .onTapGesture {
            mode = (mode == .email ? .phone : .email)
        }
    }

    @ViewBuilder
    private var otpSection: some View {
        if otpVerification != nil {
            TextField("Enter OTP", text: $verificationCode)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .padding(.horizontal)

            Button(action: verifyOTP) {
                if isVerifyingOTP {
                    ProgressView().tint(.white)
                } else {
                    Text("Verify OTP").fontWeight(.semibold)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(isVerifyingOTP)
        }
    }

    private var divider: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.5))
            Text("OR").foregroundColor(.secondary)
            Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.5))
        }
    }

    private var socialLoginButtons: some View {
        VStack(spacing: 12) {
            // Google button (prominent)
            Button {
                Task {
                    await handleSocialAuth(provider: .google)
                }
            } label: {
                HStack {
                    Image(providerImageName(.google))
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text("Continue with Google")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.white)
                .foregroundColor(.primary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(
                        Color.secondary.opacity(0.3), lineWidth: 1))
            }

            // Other social providers in a grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12
            ) {
                ForEach(
                    [
                        ProviderType.github, ProviderType.twitter, ProviderType.apple,
                        ProviderType.discord, ProviderType.facebook, ProviderType.farcaster,
                    ], id: \.self
                ) { provider in
                    Button {
                        Task {
                            await handleSocialAuth(provider: provider)
                        }
                    } label: {
                        Image(providerImageName(provider))
                            .resizable()
                            .frame(width: 24, height: 24)
                            .frame(width: 48, height: 48)
                            .background(
                                colorScheme == .dark
                                    ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)
                            )
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("By logging in, you agree to our Terms of Service & Privacy Policy.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Powered by Dynamic")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func sendOTP() {
        Task {
            isSendingOTP = true
            defer { isSendingOTP = false }
            do {
                switch mode {
                case .email:
                    otpVerification = try await sendEmailOtp(client: client, email: email)
                    message = "OTP sent to \(email)"
                case .phone:
                    otpVerification = try await sendSmsOtp(
                        client: client,
                        phoneNumber: phoneNumber,
                        phoneCountryCode: selectedCountryCode,
                        isoCountryCode: "CA"
                    )
                    message = "OTP sent to +\(selectedCountryCode) \(phoneNumber)"
                }
            } catch {
                message = "❌ Failed to send OTP: \(error.localizedDescription)"
            }
        }
    }

    private func verifyOTP() {
        guard let otpVerification else {
            message = "Missing verification data."
            return
        }

        Task {
            isVerifyingOTP = true
            defer { isVerifyingOTP = false }
            do {
                switch mode {
                case .email:
                    _ = try await verifyOtp(
                        otpVerification: otpVerification,
                        verificationToken: verificationCode
                    )
                case .phone:
                    _ = try await verifySmsOtp(
                        otpVerification: otpVerification,
                        verificationToken: verificationCode
                    )
                }
                message = "✅ Verified!"
            } catch {
                message = "❌ Verification failed: \(error.localizedDescription)"
            }
        }
    }

    private func providerImageName(_ provider: ProviderType) -> String {
        switch provider {
        case .google: return "google-logo"
        case .github: return "github-logo"
        case .twitter: return "x-logo"
        case .apple: return "apple-logo"
        case .discord: return "discord-logo"
        case .facebook: return "facebook-logo"
        case .farcaster: return "farcaster-logo"
        default: return "questionmark.circle"
        }
    }

    private func handleSocialAuth(provider: ProviderType) async {
        message = "Preparing authentication..."

        do {
            let user = try await socialLogin(
                client: client,
                with: provider,
                deepLinkUrl: "swiftdemo://"
            )
            message = "✅ Successfully logged in: \(user.email ?? "Unknown")"
        } catch {
            message = "❌ Social auth failed: \(error.localizedDescription)"
        }
    }
}

extension View {
    fileprivate func inputBoxStyle(_ scheme: ColorScheme) -> some View {
        self
            .padding()
            .background(scheme == .dark ? Color.gray.opacity(0.2) : Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary, lineWidth: 0.5))
            .padding(.horizontal)
    }
}
