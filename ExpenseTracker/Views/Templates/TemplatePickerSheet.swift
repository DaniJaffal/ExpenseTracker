//
//  TemplatePickerSheet.swift
//  ExpenseTracker
//
//  Grid of expense templates. Tapping one calls back to the parent (which
//  dismisses this sheet and opens ExpenseEditorView pre-filled from the
//  template). A "+" in the toolbar lets the user create a new template
//  without leaving the flow.
//

import SwiftUI
import SwiftData

struct TemplatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Called with the template the user tapped. The parent should dismiss
    /// the sheet and open ExpenseEditorView pre-filled.
    let onSelect: (ExpenseTemplate) -> Void

    @Query(
        sort: [
            SortDescriptor(\ExpenseTemplate.usageCount, order: .reverse),
            SortDescriptor(\ExpenseTemplate.sortOrder),
            SortDescriptor(\ExpenseTemplate.name)
        ]
    )
    private var templates: [ExpenseTemplate]

    @State private var showingAdd = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    EmptyStateView(
                        symbol: "star.circle",
                        title: "No templates yet",
                        message: "Save common expenses as one-tap templates.",
                        actionTitle: "Create Template",
                        action: { showingAdd = true }
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(templates) { template in
                                Button {
                                    onSelect(template)
                                    dismiss()
                                } label: {
                                    TemplateCard(template: template)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Use Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack { TemplateEditorView(template: nil) }
            }
        }
    }
}

// MARK: - Template card

struct TemplateCard: View {
    let template: ExpenseTemplate

    private var tint: Color { Color(hex: template.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.22))
                    Image(systemName: template.iconName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)
                Spacer()
                if template.usageCount > 0 {
                    Text("\(template.usageCount)×")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                }
            }

            Text(template.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(Formatters.currency(template.amount, in: template.currency))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            HStack(spacing: 6) {
                if let cat = template.category {
                    Image(systemName: cat.iconName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(cat.name)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                } else if let acc = template.account {
                    Text(acc.name)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                } else {
                    Text("No defaults")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .background(
            LinearGradient(
                colors: [tint, tint.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}
