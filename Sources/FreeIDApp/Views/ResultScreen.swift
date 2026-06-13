import SwiftUI
import FreeIDCore
#if canImport(UIKit)
import UIKit
import Photos
#endif

/// Shows the finished spec-sized photo with the exact pixel size, and lets the user
/// save it to Photos or share it. This is the payoff screen after a compliant capture.
struct ResultScreen: View {
    let imageData: Data
    let spec: PhotoSpec
    @Environment(\.dismiss) private var dismiss
    @State private var saveState: SaveState = .idle

    enum SaveState { case idle, saving, saved, failed }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                #if canImport(UIKit)
                if let ui = UIImage(data: imageData) {
                    Image(uiImage: ui)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 8)
                }
                #endif
                Text(spec.displayName.text(forLanguage: localeCode))
                    .font(.headline)
                Text("\(spec.pixelWidth) × \(spec.pixelHeight) px · \(Int(spec.outputSize.widthMM))×\(Int(spec.outputSize.heightMM)) mm · \(spec.dpi) dpi")
                    .font(.caption).foregroundStyle(.secondary)
                if spec.digitalEditPolicy == .strict {
                    Label("This country requires an unedited photo — background was not replaced.",
                          systemImage: "exclamationmark.shield")
                        .font(.caption).foregroundStyle(.orange)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
                Spacer()
                saveButton
                ShareLink(item: shareURL()) {
                    Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Your photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder private var saveButton: some View {
        Button {
            save()
        } label: {
            Label(saveLabel, systemImage: saveState == .saved ? "checkmark" : "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(saveState == .saving || saveState == .saved)
        .padding(.horizontal)
    }

    private var saveLabel: String {
        switch saveState {
        case .idle: return "Save to Photos"
        case .saving: return "Saving…"
        case .saved: return "Saved"
        case .failed: return "Try again"
        }
    }

    private func save() {
        #if canImport(UIKit)
        saveState = .saving
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in saveState = .failed }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, data: imageData, options: nil)
            } completionHandler: { ok, _ in
                Task { @MainActor in saveState = ok ? .saved : .failed }
            }
        }
        #endif
    }

    /// Write the JPEG to a temp file so ShareLink can share a real image file.
    private func shareURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreeID-\(spec.id).jpg")
        try? imageData.write(to: url)
        return url
    }
}
