//
//  ReceiptFieldRow.swift
//  ExpenseTracker
//
//  Reusable receipt-attachment row for editors. Handles:
//   - Empty state with attach action (Camera / Library menu)
//   - Thumbnail with tap-to-view-full-screen and edit menu (Replace / Remove)
//
//  State the editor owns:
//   - pickedImage: UIImage?     — a newly-picked image not yet on disk
//   - currentFilename: String?  — existing on-disk receipt filename
//
//  The editor handles persistence on save (see ReceiptFieldRow.commit(...)).
//

import SwiftUI
import PhotosUI

struct ReceiptFieldRow: View {
    @Binding var pickedImage: UIImage?
    @Binding var currentFilename: String?

    @State private var showingCamera = false
    @State private var showingViewer = false
    @State private var photosPickerItem: PhotosPickerItem?

    /// Whichever image we currently have to display: the newly-picked one wins.
    private var displayImage: UIImage? {
        if let pickedImage { return pickedImage }
        if let currentFilename {
            return ReceiptStore.image(named: currentFilename)
        }
        return nil
    }

    var body: some View {
        Group {
            if let image = displayImage {
                attachedView(image: image)
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $pickedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingViewer) {
            if let image = displayImage {
                ReceiptViewer(image: image)
            }
        }
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pickedImage = image
                }
                photosPickerItem = nil
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        Menu {
            Button {
                showingCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
            }
            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#5856D6").opacity(0.15))
                    Image(systemName: "doc.text.viewfinder")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(hex: "#5856D6"))
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Attach Receipt")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Camera or photo library")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
    }

    private func attachedView(image: UIImage) -> some View {
        VStack(spacing: 8) {
            Button {
                showingViewer = true
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Menu {
                            Button {
                                showingCamera = true
                            } label: {
                                Label("Replace from Camera", systemImage: "camera.fill")
                            }
                            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                                Label("Replace from Library", systemImage: "photo.on.rectangle")
                            }
                            Button(role: .destructive) {
                                removeReceipt()
                            } label: {
                                Label("Remove Receipt", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.55))
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
            }
            .buttonStyle(.plain)
            Text("Tap to view · Use menu to replace or remove")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func removeReceipt() {
        pickedImage = nil
        currentFilename = nil
    }
}

// MARK: - Editor helpers

extension ReceiptFieldRow {
    /// Persist the receipt state to a model. Call from the editor's save() with
    /// the model's current `receiptImageName` and a setter closure.
    /// Handles:
    ///  - new picked image  → write file, delete old file, set new filename
    ///  - user removed it   → delete old file, clear filename
    ///  - no change         → no-op
    static func commit(
        pickedImage: UIImage?,
        currentFilename: String?,
        originalFilename: String?,
        setFilename: (String?) -> Void
    ) {
        if let newImage = pickedImage,
           let newFilename = ReceiptStore.save(image: newImage) {
            if let original = originalFilename {
                ReceiptStore.delete(filename: original)
            }
            setFilename(newFilename)
            return
        }
        // No newly-picked image. If the original was wiped (currentFilename
        // now nil) we delete it on disk.
        if originalFilename != nil && currentFilename == nil {
            if let original = originalFilename {
                ReceiptStore.delete(filename: original)
            }
            setFilename(nil)
        }
    }
}
