//
//  TemplatesManagementView.swift
//  ExpenseTracker
//
//  Settings-side management screen — list templates, edit, delete.
//

import SwiftUI
import SwiftData

struct TemplatesManagementView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [
        SortDescriptor(\ExpenseTemplate.sortOrder),
        SortDescriptor(\ExpenseTemplate.name)
    ])
    private var templates: [ExpenseTemplate]

    @State private var editing: ExpenseTemplate?
    @State private var showingAdd = false

    var body: some View {
        Group {
            if templates.isEmpty {
                EmptyStateView(
                    symbol: "star.circle",
                    title: "No templates yet",
                    message: "Save common expenses as one-tap templates and reuse them from the + menu.",
                    actionTitle: "Add Template",
                    action: { showingAdd = true }
                )
            } else {
                List {
                    ForEach(templates) { template in
                        Button { editing = template } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(hex: template.colorHex).opacity(0.18))
                                    Image(systemName: template.iconName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color(hex: template.colorHex))
                                }
                                .frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 6) {
                                        Text(Formatters.currency(template.amount, in: template.currency))
                                            .font(.caption.monospacedDigit())
                                        if let cat = template.category {
                                            Text("·").foregroundStyle(.tertiary)
                                            Text(cat.name).font(.caption)
                                        }
                                    }
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if template.usageCount > 0 {
                                    Text("\(template.usageCount)×")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(templates[index])
                        }
                        try? context.save()
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { TemplateEditorView(template: nil) }
        }
        .sheet(item: $editing) { template in
            NavigationStack { TemplateEditorView(template: template) }
        }
    }
}
