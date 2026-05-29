//
//  WidgetRefresh.swift
//  ExpenseTracker
//
//  Tells the system to reload all of the app's widget timelines whenever data
//  that the widgets show might have changed (expenses added/edited/deleted,
//  accounts modified, transfers, etc.).
//
//  Call `WidgetRefresh.bump()` at the end of any save/delete site that changes
//  user-visible balances or recent activity. Calls are cheap and idempotent —
//  iOS coalesces them.
//

import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetRefresh {
    /// Trigger a refresh of all installed widgets for this app.
    static func bump() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
