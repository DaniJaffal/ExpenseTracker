//
//  TagFieldRow.swift
//  ExpenseTracker
//
//  Reusable "Tags" row for editors. Shows selected tags as chips in a flowing
//  layout with a trailing "+" button. Tap any chip's × to remove it; tap +
//  to open the TagPickerSheet.
//

import SwiftUI
import SwiftData

struct TagFieldRow: View {
    @Binding var selectedIDs: Set<UUID>
    let onAdd: () -> Void

    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)])
    private var allTags: [Tag]

    private var selectedTags: [Tag] {
        allTags.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(selectedTags) { tag in
                TagChip(
                    name: tag.name,
                    colorHex: tag.colorHex,
                    isSelected: true,
                    showRemove: true,
                    onRemove: { selectedIDs.remove(tag.id) }
                )
            }
            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text(selectedTags.isEmpty ? "Add tags" : "Add")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12))
                .foregroundStyle(.primary)
                .overlay(
                    Capsule().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
