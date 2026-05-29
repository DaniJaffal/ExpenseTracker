//
//  CategoryManagementView.swift
//  ExpenseTracker
//

import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.name)])
    private var categories: [Category]

    @State private var editing: Category?
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach(categories) { cat in
                Button {
                    editing = cat
                } label: {
                    HStack(spacing: 12) {
                        IconBadge(symbol: cat.iconName, color: Color(hex: cat.colorHex))
                        Text(cat.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if cat.isCustom {
                            Text("Custom")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deleteCategories)
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { CategoryEditorView(category: nil) }
        }
        .sheet(item: $editing) { cat in
            NavigationStack { CategoryEditorView(category: cat) }
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for offset in offsets {
            let cat = categories[offset]
            context.delete(cat)
        }
        try? context.save()
    }
}

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let category: Category?

    @State private var name: String = ""
    @State private var iconName: String = "tag.fill"
    @State private var colorHex: String = "#8E8E93"

    private var isEditing: Bool { category != nil }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Category name", text: $name)
            }
            Section {
                IconColorPicker(iconName: $iconName, colorHex: $colorHex)
            }
        }
        .navigationTitle(isEditing ? "Edit Category" : "New Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let cat = category {
                name = cat.name
                iconName = cat.iconName
                colorHex = cat.colorHex
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cat = category {
            cat.name = trimmed
            cat.iconName = iconName
            cat.colorHex = colorHex
        } else {
            let new = Category(
                name: trimmed,
                iconName: iconName,
                colorHex: colorHex,
                isCustom: true,
                sortOrder: 1_000
            )
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }
}
