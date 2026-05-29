//
//  ReceiptViewer.swift
//  ExpenseTracker
//
//  Full-screen receipt viewer with pinch-to-zoom.
//

import SwiftUI

struct ReceiptViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @GestureState private var pinch: CGFloat = 1.0

    private var effectiveScale: CGFloat { scale * pinch }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: proxy.size.width * max(1, effectiveScale),
                            height: proxy.size.height * max(1, effectiveScale)
                        )
                }
                .background(Color.black)
                .gesture(
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in
                            scale = max(1, min(5, scale * value))
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.25)) {
                        scale = scale > 1 ? 1 : 2.5
                    }
                }
            }
            .ignoresSafeArea()
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
