# MODEmployee - Face Verification Attendance App

A production-ready native iOS attendance application with face liveness detection, geofencing, and backend integration.

## Features

- **Employee Authentication**: Secure login with token-based authentication
- **Geofencing**: Location validation to ensure employees are at authorized sites
- **Face Liveness Detection**: On-device liveness detection using KBY-AI SDK
- **State Machine**: Robust attendance flow with explicit state management
- **Secure Storage**: Keychain integration for sensitive tokens
- **Mock Services**: Development mode with mock API responses
- **MVVM Architecture**: Clean separation of concerns with dependency injection

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.0+

## Project Structure

```
MODEmployee/
├── App/                          # Application entry point
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Features/                     # Feature modules
│   ├── Login/                    # Login flow
│   ├── Attendance/               # Attendance verification
│   └── Liveness/                 # Liveness detection
├── Services/                     # Business services
│   ├── APIClient.swift           # HTTP client
│   ├── MockAPIService.swift      # Mock API for development
│   ├── LocationService.swift     # Geofencing and location
│   ├── AuthenticationService.swift # Auth management
│   └── AttendanceService.swift   # Attendance workflow
├── Models/                       # Data models
│   ├── AttendanceState.swift
│   ├── Employee.swift
│   ├── LocationData.swift
│   ├── LivenessResult.swift
│   └── APIModels.swift
├── Security/                     # Security services
│   ├── KeychainService.swift
│   └── AppAttestService.swift
├── Liveness/                     # Liveness provider
│   ├── LivenessProvider.swift    # Protocol
│   └── KBYLivenessAdapter.swift  # KBY-AI SDK adapter
├── Configuration/                # App configuration
│   └── AppConfig.swift
└── Resources/                    # Resources
    └── Info.plist
```

## Setup Instructions

### 1. Clone and Open Project

```bash
cd MODEmployee
open MODEmployee.xcodeproj
```

### 2. Configure Project

1. Update the bundle identifier in project settings:
   - Target: MODEmployee
   - Bundle Identifier: `com.yourcompany.MODEmployee`

2. Update development team:
   - Select your team in the "Signing & Capabilities" tab

### 3. Configure API

Edit `Configuration/AppConfig.swift`:

```swift
static var apiBaseURL: String {
    switch currentEnvironment {
    case .development:
        return "https://your-dev-api.example.com"
    case .production:
        return "https://your-api.example.com"
    }
}
```

### 4. Configure Mock Mode

For development without a real backend, set:

```swift
static var useMockServices: Bool = true
```

Disable this when connecting to the real API.

## KBY-AI SDK Integration

### Current Status

The KBY-AI Face Liveness Detection SDK is **not yet integrated**. The application currently uses a mock implementation that simulates liveness detection.

### Integration Steps

To integrate the real KBY-AI SDK:

#### 1. Download SDK

Download the KBY-AI iOS Face Liveness Detection SDK from:
https://github.com/kby-ai/FaceLivenessDetection-iOS

#### 2. Add Framework to Project

1. Download the `facesdk.framework` from the KBY-AI repository
2. Drag `facesdk.framework` into your Xcode project
3. In Build Settings, add the framework to "Frameworks, Libraries, and Embedded Content"
4. Set "Embed & Sign" for the framework

#### 3. Add Bridging Header

1. Create a new file: `MODEmployee-Bridging-Header.h`
2. Add the following content:

```objc
#ifndef MODEmployee_Bridging_Header_h
#define MODEmployee_Bridging_Header_h

#import <facesdk/FaceSDK.h>

#endif
```

3. In Build Settings, set "Objective-C Bridging Header" to:
   `MODEmployee/MODEmployee-Bridging-Header.h`

#### 4. Obtain License

Contact KBY-AI to obtain a license for your bundle ID:
- Email: contact@kby-ai.com
- Telegram: @kbyaisupport
- WhatsApp: +13348402323
- Discord: KBY-AI

#### 5. Update License in AppConfig

Replace the demo license in `Configuration/AppConfig.swift`:

```swift
static var kbyLicenseKey: String {
    return "YOUR_PRODUCTION_LICENSE_KEY_HERE"
}
```

#### 6. Uncomment SDK Code in KBYLivenessAdapter

In `Liveness/KBYLivenessAdapter.swift`, uncomment the real SDK implementation code and remove the mock implementation.

#### 7. Add System Frameworks

In "Frameworks, Libraries, and Embedded Content", add:
- `AVFoundation.framework`
- `CoreMotion.framework`
- `Accelerate.framework`
- `Metal.framework`
- `MetalKit.framework`

### Testing SDK Integration

After integration, test the following:

1. Build the project - should compile without errors
2. Run on a physical device (camera not available in simulator)
3. Test liveness detection with the app
4. Verify face detection and liveness scoring

## Backend API Integration

### Required Endpoints

The application expects the following API endpoints:

#### Authentication

- `POST /auth/login`
  - Request: `LoginRequest`
  - Response: `LoginResponse`

- `POST /auth/refresh`
  - Request: `RefreshTokenRequest`
  - Response: `RefreshTokenResponse`

#### Employee

- `GET /employee/profile`
  - Response: `EmployeeProfileResponse`

#### Attendance

- `POST /attendance/verification-session`
  - Request: `VerificationSessionRequest`
  - Response: `VerificationSessionResponse`

- `POST /attendance/verify`
  - Request: `AttendanceVerificationRequest` (multipart/form-data)
  - Response: `AttendanceVerificationResponse`

#### Attendance Status

- `GET /attendance/status`
  - Response: `AttendanceStatusResponse`

### API Models

See `Models/APIModels.swift` for detailed request/response structures.

### Security Notes

1. **Never trust client-provided employee IDs** - The backend must determine the employee from the authenticated session
2. **Face matching must be server-side** - The iOS app only provides the captured image
3. **Location is a signal, not proof** - The backend should evaluate location alongside other factors
4. **Local liveness results are not tamper-proof** - Consider implementing server-verifiable sessions

## Configuration

### Environment Variables

The application uses `AppConfig` for environment-specific settings:

```swift
enum Environment {
    case development
    case production
}
```

Switch between environments using build configurations or manually.

### Feature Flags

- `useMockServices`: Enable mock API responses (development only)
- `enableDebugLogging`: Enable debug logging
- `locationAccuracyThreshold`: Required GPS accuracy in meters
- `locationTimeout`: Location acquisition timeout in seconds

## Permissions

The app requires the following permissions (configured in Info.plist):

- **Camera**: Required for face liveness detection
  - Key: `NSCameraUsageDescription`
  - Value: "Camera is used for face liveness verification during attendance check-in."

- **Location**: Required for geofencing validation
  - Key: `NSLocationWhenInUseUsageDescription`
  - Value: "Your location is used to verify you are at the authorized attendance site."

## Testing

### Unit Tests

Run unit tests with:

```bash
xcodebuild test -scheme MODEmployee -destination 'platform=iOS Simulator,name=iPhone 14'
```

Or use Xcode: Product > Test (⌘U)

### Test Coverage

Current unit tests cover:
- Geofence distance calculations
- Location accuracy validation
- Attendance state transitions
- State machine behavior

### Integration Test Plan

See the integration test plan below for comprehensive testing scenarios.

## Security Considerations

### Implemented Security Measures

1. **Keychain Storage**: Access tokens stored securely in iOS Keychain
2. **HTTPS Only**: All API communication uses HTTPS
3. **No Persistent Biometric Data**: Captured images are not stored persistently
4. **Location Validation**: Accuracy thresholds prevent spoofing
5. **State Machine**: Prevents duplicate submissions and invalid state transitions

### Security Limitations

1. **Local Liveness Results**: The KBY-AI SDK provides a local liveness score that is not cryptographically verifiable. The backend should implement additional verification.

2. **No App Attest**: Apple App Attest is implemented but not yet integrated into the flow. Consider adding it for production.

3. **Location Spoofing**: GPS coordinates can be spoofed. Location should be used as one signal among many.

### Recommended Enhancements

1. **Server-Verifiable Liveness**: Consider using an SDK that provides server-verifiable attestation (e.g., ADVANCE.AI)

2. **App Attest Integration**: Integrate Apple App Attest for device integrity verification

3. **Backend Location Validation**: Implement backend location integrity checks

4. **Rate Limiting**: Implement backend rate limiting to prevent abuse

## Integration Test Plan

### Valid Scenarios

1. **Valid Employee and Matching Face**
   - Login with valid credentials
   - Within geofence
   - Liveness detection passes
   - Attendance recorded successfully

2. **Location Accuracy**
   - Test with high accuracy GPS
   - Test with low accuracy GPS (should fail)

3. **Network Conditions**
   - Test with stable network
   - Test with slow network
   - Test with no network (should handle gracefully)

### Attack Scenarios

1. **Non-Matching Face**
   - Attempt attendance with different person
   - Should be rejected by backend face matching

2. **Printed Photo Attack**
   - Show printed photo to camera
   - Liveness detection should fail

3. **Phone Display Attack**
   - Show photo on another phone
   - Liveness detection should fail

4. **Video Replay Attack**
   - Play recorded video
   - Liveness detection should fail

5. **Location Spoofing**
   - Use GPS spoofing tools
   - Backend should detect anomalies

### Error Scenarios

1. **Camera Permission Denied**
   - User denies camera permission
   - App should handle gracefully with error message

2. **Location Permission Denied**
   - User denies location permission
   - App should handle gracefully with error message

3. **Expired Token**
   - Token expires during flow
   - App should attempt refresh

4. **Network Timeout**
   - Network request times out
   - App should show error and allow retry

5. **SDK Initialization Failure**
   - SDK fails to initialize
   - App should show appropriate error

## Troubleshooting

### Build Errors

**Error: "No such module 'Combine'"**
- Ensure iOS deployment target is 15.0+

**Error: "facesdk.framework not found"**
- Complete the KBY-AI SDK integration steps above

### Runtime Errors

**Error: "Location permission denied"**
- Check that `NSLocationWhenInUseUsageDescription` is in Info.plist
- Ensure user has granted permission in Settings

**Error: "Camera permission denied"**
- Check that `NSCameraUsageDescription` is in Info.plist
- Ensure user has granted permission in Settings

**Error: "Liveness SDK not integrated"**
- Complete the KBY-AI SDK integration steps
- Ensure bridging header is configured correctly

## Development Workflow

### Phase 1: Mock Development

1. Set `useMockServices = true` in AppConfig
2. Develop and test UI and flow
3. Test state machine transitions
4. Test location validation

### Phase 2: SDK Integration

1. Follow KBY-AI SDK integration steps
2. Test liveness detection on physical device
3. Verify image capture
4. Test liveness thresholds

### Phase 3: Backend Integration

1. Set `useMockServices = false` in AppConfig
2. Configure API base URL
3. Test authentication flow
4. Test attendance submission
5. Test error handling

### Phase 4: Production Preparation

1. Update license key to production
2. Disable debug logging
3. Set environment to production
4. Conduct security review
5. Perform integration testing

## Known Limitations

1. **KBY-AI SDK Not Integrated**: The SDK integration is not complete. Follow the integration steps above to enable real liveness detection.

2. **Simulator Limitations**: Camera and location features require a physical device for full testing.

3. **Mock API**: The mock API is a placeholder and does not represent real backend behavior.

4. **No Server-Verifiable Liveness**: The current SDK choice (KBY-AI) does not provide server-verifiable liveness results. Consider switching to ADVANCE.AI if this is required.

## Support

For questions or issues:
- KBY-AI SDK Support: contact@kby-ai.com
- Project Issues: Create an issue in the repository

## License

This project is proprietary. All rights reserved.

## Credits

- KBY-AI for Face Liveness Detection SDK
- Apple for iOS frameworks and tools
