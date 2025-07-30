import DynamicSwiftSDK
import Foundation
import SwiftUI

// MARK: - Constants
private enum Constants {
    static let defaultTransactionAmount = BigUInt(10_000_000_000_00)  // 0.0001 ETH in wei
    static let defaultGasLimit = BigUInt(21_000)  // Standard ETH transfer
    static let defaultRecipientAddress = "0xd4f748199B91c22095150d2d4Cca3Fe6175B0CbA"
    static let signatureMessage = "Hello There!"
    static let privateKeyDisplayTimeout: UInt64 = 30_000_000_000  // 30 seconds
    static let errorMessageTimeout: UInt64 = 10_000_000_000  // 10 seconds
    static let recoverySuccessTimeout: UInt64 = 3_000_000_000  // 3 seconds
}

enum NetworkOption: String, CaseIterable, Identifiable {
    case ethMainnet = "ETH Mainnet"
    case ethSepolia = "ETH Sepolia"
    case baseMainnet = "Base Mainnet"
    case baseSepolia = "Base Sepolia"
    case polygonMainnet = "Polygon Mainnet"

    var id: String { rawValue }

    var chainId: Int {
        switch self {
        case .ethMainnet: return 1
        case .ethSepolia: return 11_155_111
        case .baseMainnet: return 8453
        case .baseSepolia: return 84532
        case .polygonMainnet: return 137
        }
    }

    var explorerName: String {
        switch self {
        case .ethMainnet: return "Etherscan"
        case .ethSepolia: return "Etherscan Sepolia"
        case .baseMainnet: return "BaseScan"
        case .baseSepolia: return "BaseScan Sepolia"
        case .polygonMainnet: return "PolygonScan"
        }
    }
}

struct WalletManagementView: View {
    let credential: JwtVerifiedCredential
    let client: DynamicClient

    @State private var primaryWallet: EthereumWallet?
    @State private var signature: String?
    @State private var transactionHash: String?
    @State private var addressCopied = false
    @State private var balance: String?
    @State private var keySharesAvailable: Bool?
    @State private var isRecoveringKeyshare = false
    @State private var recoveryMessage: String?
    // Add export private key state
    @State private var exportedPrivateKey: String?
    @State private var isExportingPrivateKey = false
    @State private var exportError: String?
    @State private var selectedNetwork: NetworkOption = .baseSepolia
    @State private var isSigningMessage = false
    @State private var isSendingTransaction = false
    @State private var transactionError: String?
    @State private var transactionSuccess: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                walletInfoSection
                if let primaryWallet = primaryWallet {
                    walletDetailsSection(for: primaryWallet)
                    signatureSection
                    transactionErrorSection
                    transactionSuccessSection
                } else {
                    Text("Initializing wallet...")
                        .foregroundColor(.secondary)
                }
                walletActionsSection
            }
            .padding(.vertical)
        }
        .task {
            await initializeWallet()
            await checkKeySharesAvailability()
        }
    }

    @ViewBuilder
    private var walletInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wallet Information")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                if let walletName = credential.walletName {
                    infoRow(title: "Wallet Name", value: walletName)
                }
                if let walletProvider = credential.walletProvider {
                    infoRow(title: "Provider", value: walletProvider.rawValue)
                }
                if let chain = credential.chain {
                    infoRow(title: "Chain", value: chain)
                }
                infoRow(title: "Network", value: selectedNetwork.rawValue)
                if let publicIdentifier = credential.publicIdentifier {
                    infoRow(title: "Address", value: publicIdentifier)
                }
                keySharesStatusRow
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func walletDetailsSection(for primaryWallet: EthereumWallet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wallet Details")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    UIPasteboard.general.string = primaryWallet.address.asString()
                    addressCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        addressCopied = false
                    }
                }) {
                    HStack {
                        Text(
                            addressCopied
                                ? "Address Copied! ✓"
                                : "Address: \(primaryWallet.address.asString())"
                        )
                        .foregroundColor(addressCopied ? .blue : .primary)
                        .font(.caption)
                        Spacer()
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                if let balance = balance {
                    infoRow(title: "Balance", value: "\(balance) ETH")
                } else {
                    HStack {
                        Text("Balance:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var signatureSection: some View {
        if let signature = signature {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last Signature")
                    .font(.headline)
                Text(signature)
                    .font(.caption)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var transactionErrorSection: some View {
        if let error = transactionError {
            VStack(alignment: .leading, spacing: 8) {
                Text("Transaction Error")
                    .font(.headline)
                    .foregroundColor(.red)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var transactionSuccessSection: some View {
        if let success = transactionSuccess {
            VStack(alignment: .leading, spacing: 8) {
                Text("Transaction Success")
                    .font(.headline)
                    .foregroundColor(.green)
                Text(success)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)

                if let txHash = transactionHash {
                    Button(action: {
                        let explorerUrl = getExplorerUrl(for: selectedNetwork, txHash: txHash)
                        if let url = URL(string: explorerUrl) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("View on \(selectedNetwork.explorerName) Explorer")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var walletActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wallet Actions")
                .font(.headline)
            VStack(spacing: 12) {
                if let primaryWallet = primaryWallet {
                    walletActionButton(
                        title: isSigningMessage ? "Signing..." : "Sign Message",
                        systemImage: isSigningMessage ? "arrow.clockwise" : "signature"
                    ) {
                        signMessage(for: primaryWallet)
                    }
                    .disabled(isSigningMessage)
                    walletActionButton(
                        title: isSendingTransaction ? "Sending..." : "Send Transaction",
                        systemImage: isSendingTransaction ? "arrow.clockwise" : "paperplane"
                    ) {
                        sendTransaction(for: primaryWallet)
                    }
                    .disabled(isSendingTransaction)
                    walletActionButton(title: "Refresh Balance", systemImage: "dollarsign.circle") {
                        Task {
                            await fetchBalance(for: primaryWallet)
                        }
                    }
                    // Export Private Key button and UI
                    walletActionButton(
                        title: isExportingPrivateKey ? "Exporting..." : "Export Private Key",
                        systemImage: isExportingPrivateKey ? "arrow.clockwise" : "key.fill"
                    ) {
                        Task {
                            await exportPrivateKey(for: primaryWallet)
                        }
                    }
                    .disabled(isExportingPrivateKey)
                    if let privateKey = exportedPrivateKey {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Private Key:")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text(privateKey)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                            Button("Copy Private Key") {
                                UIPasteboard.general.string = privateKey
                            }
                            .font(.caption)
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(8)
                    }
                    if let error = exportError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    if hasKeySharesInWaasProperties() {
                        walletActionButton(
                            title: isRecoveringKeyshare ? "Recovering..." : "Recover Keyshare",
                            systemImage: isRecoveringKeyshare ? "arrow.clockwise" : "key.viewfinder"
                        ) {
                            Task {
                                await recoverKeyshare()
                            }
                        }
                        .disabled(isRecoveringKeyshare)
                        if let recoveryMessage = recoveryMessage {
                            Text(recoveryMessage)
                                .font(.caption)
                                .foregroundColor(recoveryMessage.contains("✅") ? .green : .red)
                                .padding(.horizontal)
                        }
                    }
                    Picker("Select Network", selection: $selectedNetwork) {
                        ForEach(NetworkOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedNetwork) { _, _ in
                        Task {
                            await fetchBalance(for: primaryWallet)
                        }
                    }
                } else {
                    Text("Loading wallet...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    @ViewBuilder
    private func walletActionButton(
        title: String, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var keySharesStatusRow: some View {
        HStack {
            Text("Key Shares:")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if let available = keySharesAvailable {
                Text(available ? "Available" : "Not Found")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(available ? .green : .red)
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    // MARK: - Wallet Operations
    private func initializeWallet() async {
        guard let address = credential.publicIdentifier else { return }
        do {
            primaryWallet = try EthereumWallet(address: address, client: client)
            if let wallet = primaryWallet {
                await fetchBalance(for: wallet)
            }
        } catch {
            // Handle error appropriately for production
        }
    }

    private func fetchBalance(for wallet: EthereumWallet) async {
        do {
            // Switch to the selected network
            if let supportedNetwork = SupportedEthereumNetwork.fromChainId(selectedNetwork.chainId)
            {
                try await wallet.switchNetwork(to: supportedNetwork.chainConfig)
            } else {
                await MainActor.run { balance = "Unsupported Network" }
                return
            }

            // Now get balance
            let balanceWei = try await wallet.getBalance(.Latest)

            // Convert Wei (BigUInt) to Ether (Double)
            guard let etherValue = Double(String(balanceWei)) else {
                await MainActor.run {
                    balance = "Error"
                }
                return
            }
            let etherInDecimals = etherValue / pow(10.0, 18.0)
            let balanceEth = String(format: "%.6f", etherInDecimals)

            await MainActor.run {
                balance = balanceEth
            }
        } catch {
            await MainActor.run {
                balance = "Error"
            }
        }
    }

    private func signMessage(for wallet: EthereumWallet) {
        Task {
            await MainActor.run {
                isSigningMessage = true
            }

            let message = Constants.signatureMessage

            do {
                let sig = try await wallet.signMessage(message)
                await MainActor.run {
                    signature = sig
                }
            } catch {
                await MainActor.run {
                    signature = nil
                }
            }

            if let signature = signature {
                _ = try verifySignature(
                    message: message, signature: signature,
                    walletAddress: wallet.accountAddress.asString())
                // Handle verification result appropriately for production
            }

            await MainActor.run {
                isSigningMessage = false
            }
        }
    }

    private func sendTransaction(for wallet: EthereumWallet) {
        Task {
            await MainActor.run {
                isSendingTransaction = true
                transactionError = nil
                transactionSuccess = nil
            }

            let amount = Constants.defaultTransactionAmount
            let chainId = selectedNetwork.chainId
            let recipient = EthereumAddress(Constants.defaultRecipientAddress)

            do {
                // Switch to the selected network first
                if let supportedNetwork = SupportedEthereumNetwork.fromChainId(chainId) {
                    try await wallet.switchNetwork(to: supportedNetwork.chainConfig)
                }

                let networkClient: BaseEthereumClient = try await wallet.getNetworkClient(
                    for: chainId)

                let gasPrice = try await networkClient.eth_gasPriceBigInt()
                let gasLimit = Constants.defaultGasLimit

                let transaction = EthereumTransaction(
                    from: wallet.address,
                    to: recipient,
                    value: amount,
                    data: Data(),
                    nonce: nil,
                    gasPrice: gasPrice,
                    gasLimit: gasLimit,
                    chainId: chainId
                )

                let txHash = try await wallet.sendTransaction(transaction)

                await MainActor.run {
                    transactionHash = txHash
                    transactionSuccess = "✅ Transaction sent successfully!"
                }

                // Clear success message after 10 seconds
                Task {
                    try? await Task.sleep(nanoseconds: Constants.errorMessageTimeout)
                    await MainActor.run {
                        transactionSuccess = nil
                    }
                }
            } catch {
                await MainActor.run {
                    transactionError = "❌ Transaction failed: \(error.localizedDescription)"
                }
            }

            await MainActor.run {
                isSendingTransaction = false
            }

            // Clear error message after 10 seconds
            if transactionError != nil {
                Task {
                    try? await Task.sleep(nanoseconds: Constants.errorMessageTimeout)
                    await MainActor.run {
                        transactionError = nil
                    }
                }
            }
        }
    }

    private func checkKeySharesAvailability() async {
        guard let address = credential.publicIdentifier else {
            await MainActor.run {
                keySharesAvailable = false
            }
            return
        }

        let keyShares = loadKeyShares(client: client, accountAddress: address)
        await MainActor.run {
            keySharesAvailable = keyShares != nil
        }
    }

    private func hasKeySharesInWaasProperties() -> Bool {
        guard let walletProperties = credential.walletProperties,
            let waasProperties = walletProperties.value5,
            let keyShares = waasProperties.keyShares,
            !keyShares.isEmpty
        else {
            return false
        }
        return true
    }

    private func getKeyShareIds() -> [Uuid]? {
        guard let walletProperties = credential.walletProperties,
            let waasProperties = walletProperties.value5,
            let keyShares = waasProperties.keyShares
        else {
            return nil
        }

        return keyShares.map { $0.id }
    }

    private func getExplorerUrl(for network: NetworkOption, txHash: String) -> String {
        switch network {
        case .ethMainnet:
            return "https://etherscan.io/tx/\(txHash)"
        case .ethSepolia:
            return "https://sepolia.etherscan.io/tx/\(txHash)"
        case .baseMainnet:
            return "https://basescan.org/tx/\(txHash)"
        case .baseSepolia:
            return "https://sepolia.basescan.org/tx/\(txHash)"
        case .polygonMainnet:
            return "https://polygonscan.com/tx/\(txHash)"
        }
    }

    private func recoverKeyshare() async {
        await MainActor.run {
            isRecoveringKeyshare = true
            recoveryMessage = nil
        }

        let walletId = credential.id

        guard let keyShareIds = getKeyShareIds() else {
            await MainActor.run {
                recoveryMessage = "❌ No keyshare IDs found"
                isRecoveringKeyshare = false
            }
            return
        }

        do {
            if let wallet = primaryWallet {

                _ = try await recoverEncryptedBackupByWallet(
                    client: client,
                    walletId: walletId,
                    keyShareIds: keyShareIds,
                    address: wallet.address.asString()
                )
                await MainActor.run {
                    recoveryMessage = "✅ Keyshare recovered successfully!"
                    isRecoveringKeyshare = false
                }

                // Refresh the keyshares availability status
                await checkKeySharesAvailability()

                // Clear success message after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: Constants.recoverySuccessTimeout)
                    await MainActor.run {
                        if recoveryMessage?.contains("✅") == true {
                            recoveryMessage = nil
                        }
                    }
                }
            }

        } catch {
            await MainActor.run {
                recoveryMessage = "❌ Recovery failed: \(error.localizedDescription)"
                isRecoveringKeyshare = false
            }
        }
    }

    // Add exportPrivateKey function
    private func exportPrivateKey(for wallet: EthereumWallet) async {
        await MainActor.run {
            isExportingPrivateKey = true
            exportError = nil
            exportedPrivateKey = nil
        }
        do {
            let privateKey = try await wallet.exportPrivateKey()
            await MainActor.run {
                exportedPrivateKey = privateKey
                isExportingPrivateKey = false
            }
            // Clear the private key from display after 30 seconds
            Task {
                try? await Task.sleep(nanoseconds: Constants.privateKeyDisplayTimeout)
                await MainActor.run {
                    exportedPrivateKey = nil
                }
            }
        } catch {
            await MainActor.run {
                exportError = "❌ Export failed: \(error.localizedDescription)"
                isExportingPrivateKey = false
            }
            // Clear error message after 10 seconds
            Task {
                try? await Task.sleep(nanoseconds: Constants.errorMessageTimeout)
                await MainActor.run {
                    exportError = nil
                }
            }
        }
    }
}
