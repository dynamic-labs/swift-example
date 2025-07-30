import DynamicSwiftSDK
import SwiftUI

// MARK: - Constants
private enum Constants {
    static let defaultEnvironmentId = "7827b36d-e5f8-459f-aff9-4ff7508dc94d"
}

struct ContentView: View {
    @State private var client: DynamicClient?

    // This should be placed in the file where client is created, and should control which view
    @StateObject private var sessionState = DynamicSessionState()

    @State private var message: String = ""

    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                (colorScheme == .dark
                    ? LinearGradient(
                        gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.black]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Text("Dynamic Swift Demo App")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top)
                        .foregroundColor(.primary)

                    if !sessionState.isInitialized {
                        Spacer()
                        ProgressView("Initializing SDK...")
                            .scaleEffect(1.5)
                            .tint(.blue)
                        Spacer()
                    } else if let client {
                        if sessionState.isLoggedIn {
                            AuthenticatedView(
                                client: client,
                                onLogout: {
                                    message = "👋 Logged out"
                                }
                            )
                            .transition(.slide)
                        } else {
                            UnauthenticatedView(
                                client: client,
                                message: $message
                            )
                            .transition(.slide)
                        }

                        Text(message)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut, value: message)

                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .animation(.default, value: sessionState.isLoggedIn)
        }
        .task {
            await initialize()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            Task {
                await refreshSettingsIfNeeded()
            }
        }
    }

    private func initialize() async {
        let config = DynamicClientConfig(
            environmentId:
                ProcessInfo.processInfo.environment["DYNAMIC_ENVIRONMENT_ID"]
                ?? Constants.defaultEnvironmentId
        )

        let newClient = createDynamicClient(config: config)

        client = newClient
        bindSessionState(sessionState, to: newClient)

        do {
            try await addEthereumConnector(
                to: newClient,
                networkConfigProvider: GenericNetworkConfigurationProvider(),
                initialChainId: 84532  // Base Testnet
            )
        } catch {
            // Handle error appropriately for production
        }
    }

    private func refreshSettingsIfNeeded() async {
        guard let existingClient = client else { return }
        do {
            try await initializeClient(client: existingClient)
        } catch {
            // Handle error appropriately for production
        }
    }
}
