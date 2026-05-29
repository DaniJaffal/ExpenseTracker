//
//  ExpenseTrackerWidgetBundle.swift
//  ExpenseTrackerWidget
//
//  Registers all of the app's home screen widgets.
//

import WidgetKit
import SwiftUI

@main
struct ExpenseTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TotalBalanceWidget()
        AccountBalanceWidget()
        QuickAddWidget()
        QuickLogWidget()
    }
}
