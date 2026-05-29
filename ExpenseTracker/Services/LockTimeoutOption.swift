//
//  LockTimeoutOption.swift
//  ExpenseTracker
//
//  Enum-of-Int wrapper around the lock timeout values stored on AppSettings.
//

import Foundation

enum LockTimeoutOption: Int, CaseIterable, Identifiable, Sendable {
    case immediately    = 0
    case oneMinute      = 60
    case fiveMinutes    = 300
    case fifteenMinutes = 900
    case oneHour        = 3600
    case launchOnly     = -1

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .immediately:    return "Immediately"
        case .oneMinute:      return "After 1 minute"
        case .fiveMinutes:    return "After 5 minutes"
        case .fifteenMinutes: return "After 15 minutes"
        case .oneHour:        return "After 1 hour"
        case .launchOnly:     return "Only at launch"
        }
    }

    static func option(forStoredValue raw: Int) -> LockTimeoutOption {
        Self(rawValue: raw) ?? .immediately
    }
}
