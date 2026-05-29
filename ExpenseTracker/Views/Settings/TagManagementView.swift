//
//  TagManagementView.swift
//  ExpenseTracker
//
//  Manage tags — rename, recolor, delete.
//

import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)])
    private var tags: [Tag]

    @State private var editing: Tag?
    @State private var showingAdd = false

    var body: some View {
        Group {
            if tags.isEmpty {
                EmptyStateView(
                    symbol: "tag.circle",
                    title: "No tags yet",
                    message: "Create cross-cutting labels like \"Work trip\", \"Christmas\", or \"Family\".",
                    actionTitle: "Add Tag",
                    action: { showingAdd = true }
                )
            } else {
                List {
                    ForEach(tags) { tag in
                        Button { editing = tag } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: tag.colorHex))
                                    .frame(width: 14, height: 14)
                                Text(tag.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(tag.expenses?.count ?? 0) + \(tag.incomes?.count ?? 0)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(tags[index])
                        }
                        try? context.save()
                    }
                }
            }
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack { TagEditorView(tag: nil) }
        }
        .sheet(item: $editing) { tag in
            NavigationStack { TagEditorView(tag: tag) }
        }
    }
}

struct TagEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let tag: Tag?

    @State private var name: String = ""
    @State private var colorHex: String = "#5856D6"

    private var isEditing: Bool { tag != nil }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Tag name", text: $name)
                    .autocorrectionDisabled()
            }
            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                    ForEach(Palette.pickable, id: \.self) { hex in
                        Button { colorHex = hex } label: {
                            ZStack {
                                Circle().fill(Color(hex: hex))
                                if colorHex.lowercased() == hex.lowercased() {
                                    Circle().strokeBorder(Color.primary, lineWidth: 2).padding(2)
                                }
                            }
                            .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Tag" : "New Tag")
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
            if let t = tag {
                name = t.name
                colorHex = t.colorHex
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = tag {
            t.name = trimmed
            t.colorHex = colorHex
        } else {
            let new = Tag(name: trimmed, colorHex: colorHex)
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }
}
