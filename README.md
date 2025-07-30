# Dynamic Swift + SwiftUI Example App

Welcome to the Dynamic Swift + SwiftUI Example App! This repository contains a simple iOS application demonstrating how to integrate the Dynamic product with Swift using SwiftUI.

## Requirements

Before you begin, make sure you have:

- **iOS 13.0+** - The SDK requires iOS 13.0 or later
- **Swift 5.9+** - Modern Swift features are used throughout
- **Xcode 15.0+** - For the best development experience
- **Dynamic Account** - Set up your project and get an environment ID from [Dynamic Dashboard](https://app.dynamic.xyz/dashboard/overview)

You will also need to enable the SMS and/or Email Login options to have a login method available in the example app.

## Installation

Follow these steps to get the app up and running:

1. **Set Up Your Environment**

   Prepare your development environment for iOS development by following the official setup guide: [iOS Development Setup](https://developer.apple.com/develop/).

2. **Clone the repository:**

   ```bash
   git clone https://github.com/your-username/swift-demo.git
   cd swift-demo
   ```

3. **Open the project in Xcode:**

   ```bash
   open SwiftDemo.xcodeproj
   ```

4. **Configure Environment Variables:**

   The SDK needs to know which Dynamic environment to connect to. You'll need to set up environment variables in your Xcode scheme:

   1. In Xcode, go to **Product → Scheme → Edit Scheme**
   2. Select **"Run"** from the left sidebar
   3. Go to the **"Arguments"** tab
   4. Under **"Environment Variables"**, add the following:

   ```
   DYNAMIC_BASE_URL = https://app.dynamicauth.com/api/v0
   DYNAMIC_RELAY_HOST = relay.dynamicauth.com
   DYNAMIC_ENVIRONMENT_ID = <your_environment_id>
   ```

   Replace `<your_environment_id>` with the environment ID from your Dynamic dashboard.

   **Alternative: Update the Default Value**

   In `SwiftDemo/UI/ContentView.swift`, update the `defaultEnvironmentId` constant:

   ```swift
   static let defaultEnvironmentId = "your-environment-id-here"
   ```

5. **Enable Features in Dashboard:**

   Before you can use authentication and wallet features, you need to enable them in your Dynamic dashboard:

   1. Go to your [Dynamic Dashboard](https://app.dynamic.xyz/dashboard/overview)
   2. Select your project
   3. Go to **Authentication** and enable the methods you want to use:
      - Email OTP
      - SMS OTP
      - Social providers (Apple, Google, etc.)
   4. Go to **Wallets** and enable embedded wallets
   5. Go to **Chains** and enable the networks you want to support

6. **Build and Run:**

   - Select your target device (iOS Simulator or physical device)
   - Press `Cmd + R` or click the "Run" button in Xcode

## Features

This example app demonstrates the following Dynamic features:

- **Authentication Methods:**

  - Email OTP (One-Time Password)
  - SMS OTP
  - Social Login (Google, GitHub, Twitter/X, Apple, Discord, Facebook, Farcaster)

- **User Management:**

  - User session management
  - Token display and copying
  - Logout functionality

- **Wallet Integration:**

  - Ethereum wallet creation
  - Wallet management interface
  - Verified credentials display

- **UI Components:**
  - Modern SwiftUI interface with dark/light mode support
  - Smooth animations and transitions
  - Responsive design for different screen sizes

## Project Structure

For further development, you may find the following files relevant:

- **App Entry Point:** `SwiftDemo/SwiftDemoApp.swift`
- **Main Content View:** `SwiftDemo/UI/ContentView.swift`
- **Authentication Views:**
  - `SwiftDemo/UI/Auth/UnauthenticatedView.swift` - Login and signup interface
  - `SwiftDemo/UI/Auth/AuthenticatedView.swift` - Post-login user interface
- **Wallet Management:**
  - `SwiftDemo/UI/Wallet/WalletView.swift` - Wallet operations
  - `SwiftDemo/UI/Wallet/WalletManagementView.swift` - Wallet management
  - `SwiftDemo/UI/Wallet/VerifiedCredentialsView.swift` - Display verified credentials

## Configuration

### Dynamic Client Setup

The Dynamic client is initialized in `ContentView.swift` with the following configuration:

```swift
let config = DynamicClientConfig(
    environmentId: ProcessInfo.processInfo.environment["DYNAMIC_ENVIRONMENT_ID"]
        ?? Constants.defaultEnvironmentId
)
```

### Network Configuration

The app is configured to use Base Sepolia (Chain ID: 84532) by default. You can modify this in the `initialize()` function:

```swift
try await addEthereumConnector(
    to: newClient,
    networkConfigProvider: GenericNetworkConfigurationProvider(),
    initialChainId: 84532  // Change this to your preferred network
)
```

## Troubleshooting

### Common Issues

**"Could not find module 'DynamicSwiftSDK'"**

- Make sure you've added the package to your target
- Try cleaning the build folder (Product → Clean Build Folder)
- Restart Xcode

**"Environment ID not found"**

- Check that you've set the `DYNAMIC_ENVIRONMENT_ID` environment variable
- Verify the environment ID in your Dynamic dashboard
- Make sure you're using the correct environment (sandbox vs live)

**"Network connection failed"**

- Check your internet connection
- Verify the `DYNAMIC_BASE_URL` and `DYNAMIC_RELAY_HOST` environment variables
- Ensure your environment is active in the Dynamic dashboard

**Build Errors:**

- Ensure you have the latest version of Xcode installed
- Clean the build folder (`Cmd + Shift + K`) and rebuild
- Check that all dependencies are properly resolved

**Authentication Issues:**

- Verify your Dynamic environment ID is correct
- Ensure you have enabled the authentication methods you want to test in your Dynamic dashboard
- Check that your app's bundle identifier matches your Dynamic project configuration

**Simulator Issues:**

- If using social login, you may need to test on a physical device as some providers don't work well in the simulator
- Ensure you have the latest iOS Simulator installed

### Getting Help

If you're experiencing issues with the Dynamic SDK specifically, check the [Dynamic Swift Documentation](https://docs.dynamic.xyz/swift/introduction) for detailed integration guides and troubleshooting tips.

## Documentation

For more detailed information on integrating Dynamic with Swift, please refer to our official documentation: [Dynamic Swift Integration](https://docs.dynamic.xyz/swift/introduction).
