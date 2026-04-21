# Build Instructions for React Native Health

## Prerequisites
- Node.js (version 14 or higher)
- npm (version 6 or higher)
- React Native CLI
- Xcode (for iOS development)
- Android Studio (for Android development)

## Local Build Steps
1. **Clone the repository**:
   ```bash
   git clone https://github.com/Hello-Heart/react-native-health.git
   cd react-native-health
   ```
2. **Install dependencies**:
   ```bash
   npm install
   ```
3. **Run the application**:
   - For iOS:
     ```bash
     npx react-native run-ios
     ```
   - For Android:
     ```bash
     npx react-native run-android
     ```

## Available Scripts
- `npm start`: Starts the development server.
- `npm test`: Runs the test suite.
- `npm run build`: Builds the application for production.

## Troubleshooting Guide
- **Build Failed**: Ensure that all prerequisites are installed and the correct versions are being used.
- **Package not found**: Run `npm install` to ensure all dependencies are installed.
- **Device not connected**: Ensure your device/simulator is properly connected and recognized by your computer.