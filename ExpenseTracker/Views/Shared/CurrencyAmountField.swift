//
//  CurrencyAmountField.swift
//  ExpenseTracker
//
//  Reusable amount input: decimal text field + currency picker.
//

import SwiftUI

struct CurrencyAmountField: View {
    let title: String
    @Binding var amount: Decimal
    @Binding var currency: Currency

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            TextField(
                "0",
                value: $amount,
                format: .number.precision(.fractionLength(0...currency.defaultFractionDigits))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.title3.monospacedDigit())

            Picker("", selection: $currency) {
                ForEach(Currency.allCases) { c in
                    Text(c.displayCode).tag(c)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(.primary)
        }
        .padding(.vertical, 4)
    }
}

/// Optional variant — toggle on/off, used for "money returned".
struct OptionalCurrencyAmountField: View {
    let title: String
    @Binding var amount: Decimal?
    @Binding var currency: Currency?

    private var isOn: Bool { amount != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { isOn },
                set: { newValue in
                    if newValue {
                        amount = 0
                        if currency == nil { currency = .usd }
                    } else {
                        amount = nil
                        currency = nil
                    }
                }
            )) {
                Text(title)
            }

            if isOn {
                HStack(spacing: 12) {
                    TextField(
                        "0",
                        value: Binding(
                            get: { amount ?? 0 },
                            set: { amount = $0 }
                        ),
                        format: .number.precision(.fractionLength(0...(currency ?? .usd).defaultFractionDigits))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.monospacedDigit())

                    Picker("", selection: Binding(
                        get: { currency ?? .usd },
                        set: { currency = $0 }
                    )) {
                        ForEach(Currency.allCases) { c in
                            Text(c.displayCode).tag(c)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
            }
        }
    }
}
