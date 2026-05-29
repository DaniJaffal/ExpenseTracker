//
//  TagPickerSheet.swift
//  ExpenseTracker
//
//  Modal sheet for selecting tags on an expense or income. Multi-select with
//  checkmarks. "Create new tag" inline at the bottom.
//

import SwiftUI
import SwiftData

struct TagPickerSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// IDs of currently selected tags. Two-way binding so the editor sees changes.
    @Binding var selectedIDs: Set<UUID>

    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)])
    private var allTags: [Tag]

    @State private var newTagName: String = ""
    @State private var newTagColor: String = "#5856D6"
    @State private var searchText: String = ""

    private var filtered: [Tag] {
        if searchText.isEmpty { return allTags }
        let q = searchText.lowercased()
        return allTags.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if allTags.isEmpty {
                    Section {
                        VStack(spacing: 6) {
                            Image(systemName: "tag.circle")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("No tags yet")
                                .font(.subheadline.weight(.semibold))
                            Text("Create one below.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                } else {
                    Section {
                        ForEach(filtered) { tag in
                            Button { toggle(tag) } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color(hex: tag.colorHex))
                                        .frame(width: 12, height: 12)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedIDs.contains(tag.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color(hex: tag.colorHex))
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteTag(tag)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("Create new tag") {
                    TextField("Tag name", text: $newTagName)
                        .autocorrectionDisabled()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Color").font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), spacing: 10) {
                            ForEach(Palette.pickable, id: \.self) { hex in
                                Button { newTagColor = hex } label: {
                                    ZStack {
                                        Circle().fill(Color(hex: hex))
                                        if newTagColor.lowercased() == hex.lowercased() {
                                            Circle().strokeBorder(Color.primary, lineWidth: 2).padding(2)
                                        }
                                    }
                                    .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button(action: createTag) {
                        Label("Create tag", systemImage: "plus.circle.fill")
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .searchable(text: $searchText, prompt: "Search tags")
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ tag: Tag) {
        if selectedIDs.contains(tag.id) {
            selectedIDs.remove(tag.id)
        } else {
            selectedIDs.insert(tag.id)
        }
    }

    private func createTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newTag = Tag(
            name: trimmed,
            colorHex: newTagColor,
            sortOrder: (allTags.last?.sortOrder ?? 0) + 1
        )
        context.insert(newTag)
        try? context.save()
        selectedIDs.insert(newTag.id)
        newTagName = ""
    }

    private func deleteTag(_ tag: Tag) {
        selectedIDs.remove(tag.id)
        context.delete(tag)
        try? context.save()
    }
}
