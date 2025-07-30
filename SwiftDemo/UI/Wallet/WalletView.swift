import DynamicSwiftSDK
import SwiftUI

struct WalletView: View {
    let client: DynamicClient

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let verifiedCredentials = client.user?.verifiedCredentials {
                    VerifiedCredentialsView(
                        verifiedCredentials: verifiedCredentials, client: client
                    )
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                } else {
                    Text("No verified credentials found")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }
}
