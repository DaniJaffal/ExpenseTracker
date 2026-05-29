//
//  BiometricAuthService.swift
//  ExpenseTracker
//
//  Thin wrapper around LocalAuthentication for unlock prompts. Uses
//  `deviceOwnerAuthentication` so if biometrics fail (or aren't enrolled),
//  iOS automatically falls back to the device passcode.
//

import Foundation
import LocalAuthentication

enum BiometricKind {
    case none
    case touchID
    case faceID
    case opticID

    /// Title used in Settings ("Require Face ID", etc.).
    var settingsLabel: String {
        switch self {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none:    return "Passcode"
        }
    }

    var systemImage: String {
        switch self {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none:    return "lock.fill"
        }
    }
}

@MainActor
enum BiometricAuthService {

    /// What kind of biometric the device supports right now. Returns `.none`
    /// when biometrics aren't enrolled or aren't available (e.g. simulator
    /// without Face ID enrolled in Features menu).
    static func availableBiometric() -> BiometricKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default:       return .none
        }
    }

    /// Prompts the user to authenticate. Uses biometric first, falling back to
    /// device passcode automatically. Returns true on success, false on cancel
    /// / failure / error.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
