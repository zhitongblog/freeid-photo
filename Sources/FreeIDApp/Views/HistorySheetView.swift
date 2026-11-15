import SwiftUI
import FreeIDCore
#if canImport(UIKit)
import UIKit
#endif

/// Sheet showing recent upright originals saved locally on device. Tapping any photo
/// immediately exports it to `model.selectedSpec` and opens `ResultScreen` — no re-shooting.
struct HistorySheetView: View {
    @Bindable var model: CaptureViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 108, maximum: 160), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if model.historyEntries.isEmpty {
                    ContentUnavailableView {
                        Label(S.historyTitle.t, systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text(S.historyEmpty.t)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(S.historyNote.t)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(model.historyEntries) { entry in
                                    card(for: entry)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(S.historyTitle.t)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(S.done.t) { dismiss() }
                }
                if !model.historyEntries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            model.clearHistory()
                        } label: {
                            Text(S.clearHistory.t)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func card(for entry: PhotoHistoryStore.Entry) -> some View {
        Button {
            dismiss()
            model.loadHistoryEntry(entry)
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    thumbnail(for: entry.id)
                        .frame(height: 136)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text(entry.createdAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Button(role: .destructive) {
                    model.deleteHistoryEntry(entry.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.callout)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                        .padding(10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(S.deleteItem.t)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func thumbnail(for id: UUID) -> some View {
        #if canImport(UIKit)
        if let data = model.historyStore.imageData(for: id), let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            Color.secondary.opacity(0.15)
        }
        #else
        Color.secondary.opacity(0.15)
        #endif
    }
}
