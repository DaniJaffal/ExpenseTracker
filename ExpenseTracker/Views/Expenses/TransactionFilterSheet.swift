//
//  TransactionFilterSheet.swift
//  ExpenseTracker
//
//  Modal sheet that edits all filter criteria. Chips for multi-select fields,
//  a Picker for date range with conditional DatePickers when "Custom" is
//  selected, two-field amount range, and a receipts-only toggle.
//

import SwiftUI
import SwiftData

struct TransactionFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var state: TransactionFilterState

    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.name)])
    private var categories: [Category]
    @Query(sort: [SortDescriptor(\IncomeSource.sortOrder), SortDescriptor(\IncomeSource.name)])
    private var sources: [IncomeSource]
    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.name)])
    private var accounts: [Account]
    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    var body: some View {
        NavigationStack {
            Form {
                Section("Date range") {
                    Picker("Range", selection: $state.dateRangePreset) {
                        ForEach(DateRangePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    if state.dateRangePreset == .custom {
                        DatePicker("From", selection: $state.customStart, displayedComponents: .date)
                        DatePicker("To", selection: $state.customEnd, in: state.customStart..., displayedComponents: .date)
                    }
                }

                if !categories.isEmpty {
                    Section {
                        chipFlow(
                            items: categories.map { ($0.id, $0.name, $0.iconName, $0.colorHex) },
                            selected: $state.selectedCategoryIDs
                        )
                    } header: {
                        chipHeader(title: "Categories", count: state.selectedCategoryIDs.count) {
                            state.selectedCategoryIDs.removeAll()
                        }
                    }
                }

                if !sources.isEmpty {
                    Section {
                        chipFlow(
                            items: sources.map { ($0.id, $0.name, $0.iconName, $0.colorHex) },
                            selected: $state.selectedSourceIDs
                        )
                    } header: {
                        chipHeader(title: "Income sources", count: state.selectedSourceIDs.count) {
                            state.selectedSourceIDs.removeAll()
                        }
                    }
                }

                if !accounts.isEmpty {
                    Section {
                        chipFlow(
                            items: accounts.map { ($0.id, $0.name, $0.iconName, $0.colorHex) },
                            selected: $state.selectedAccountIDs
                        )
                    } header: {
                        chipHeader(title: "Accounts", count: state.selectedAccountIDs.count) {
                            state.selectedAccountIDs.removeAll()
                        }
                    }
                }

                if !tags.isEmpty {
                    Section {
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(tags) { tag in
                                Button {
                                    toggle(tag.id, in: &state.selectedTagIDs)
                                } label: {
                                    TagChip(
                                        name: tag.name,
                                        colorHex: tag.colorHex,
                                        isSelected: state.selectedTagIDs.contains(tag.id)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        chipHeader(title: "Tags", count: state.selectedTagIDs.count) {
                            state.selectedTagIDs.removeAll()
                        }
                    }
                }

                Section("Amount range") {
                    HStack {
                        Text("Min").foregroundStyle(.secondary)
                        Spacer()
                        TextField("any", value: $state.minAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                    HStack {
                        Text("Max").foregroundStyle(.secondary)
                        Spacer()
                        TextField("any", value: $state.maxAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                }

                Section {
                    Toggle(isOn: $state.receiptsOnly) {
                        Label("Only with receipts", systemImage: "paperclip")
                    }
                }

                if state.hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            state.reset()
                        } label: {
                            Label("Reset all filters", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func toggle(_ id: UUID, in set: inout Set<UUID>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }

    private func chipFlow(
        items: [(id: UUID, name: String, icon: String, color: String)],
        selected: Binding<Set<UUID>>
    ) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(items, id: \.id) { item in
                Button {
                    if selected.wrappedValue.contains(item.id) {
                        selected.wrappedValue.remove(item.id)
                    } else {
                        selected.wrappedValue.insert(item.id)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.caption.weight(.semibold))
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        selected.wrappedValue.contains(item.id)
                            ? Color(hex: item.color).opacity(0.18)
                            : Color.secondary.opacity(0.10)
                    )
                    .foregroundStyle(
                        selected.wrappedValue.contains(item.id)
                            ? Color(hex: item.color)
                            : .primary
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            selected.wrappedValue.contains(item.id)
                                ? Color(hex: item.color).opacity(0.5)
                                : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func chipHeader(title: String, count: Int, onClear: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            if count > 0 {
                Text("(\(count))").foregroundStyle(.secondary)
                Spacer()
                Button("Clear", action: onClear)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "#0A84FF"))
                    .textCase(nil)
            }
        }
    }
}
