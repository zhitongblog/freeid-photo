import SwiftUI
import FreeIDCore
#if canImport(UIKit)
import UIKit
import Photos
#endif

/// Shows the finished spec-sized photo, lets the user pick a background color (re-exported
/// instantly), and save or share it. The payoff screen after a capture.
struct ResultScreen: View {
    @Bindable var model: CaptureViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var saveState: SaveState = .idle

    enum SaveState { case idle, saving, saved, failed }

    private var spec: PhotoSpec { model.selectedSpec }
    private var imageData: Data? { model.exportedData }
    /// The spec's required background color name, localized, e.g. "白色" / "white".
    private var bgName: String { SpecText.colorName(spec.background.hex) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer(minLength: 8)
                #if canImport(UIKit)
                if let data = imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 8)
                }
                #endif
                Label(S.readyToUse.t, systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(.green)
                Text("\(SpecText.name(spec)) · \(spec.pixelWidth)×\(spec.pixelHeight)px")
                    .font(.caption).foregroundStyle(.secondary)

                if model.canChooseBackground {
                    backgroundPicker
                } else if model.backgroundLockedToSpec {
                    // Editable official doc: background was set to the REQUIRED color, not a choice.
                    Label(String(format: S.requiredBgNote.t, bgName), systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                } else {
                    Label(String(format: S.strictBgWarning.t, bgName), systemImage: "exclamationmark.shield")
                        .font(.caption).foregroundStyle(.orange)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                Spacer(minLength: 8)
                saveButton
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Label(S.retake.t, systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    if let data = imageData {
                        ShareLink(item: shareURL(data)) {
                            Label(S.share.t, systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)

                Link(destination: Brand.url) {
                    HStack(spacing: 0) {
                        Text(Brand.creditPrefix.t)
                        BrandWordmark(size: 13)
                        Text(Brand.creditSuffix.t)
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
            }
            .navigationTitle(S.yourPhoto.t)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(S.done.t) { dismiss() }
                }
            }
        }
    }

    /// Row of background color swatches; tapping re-exports the shot in that color.
    private var backgroundPicker: some View {
        VStack(spacing: 8) {
            Text(S.backgroundLabel.t).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                ForEach(CaptureViewModel.BackgroundChoice.all) { choice in
                    let selected = model.backgroundHex == choice.hex
                    Button {
                        if saveState == .saved { saveState = .idle } // new color → allow re-save
                        model.chooseBackground(choice.hex)
                    } label: {
                        Circle()
                            .fill(Color(hex: choice.hex))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(.gray.opacity(0.4), lineWidth: 1))
                            .overlay(Circle().stroke(.tint, lineWidth: selected ? 3 : 0).padding(-3))
                    }
                    .accessibilityLabel(choice.name)
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
        .disabled(saveState == .saving || saveState == .saved || imageData == nil)
        .padding(.horizontal)
    }

    private var saveLabel: String {
        switch saveState {
        case .idle: return S.saveToPhotos.t
        case .saving: return S.saving.t
        case .saved: return S.saved.t
        case .failed: return S.tryAgain.t
        }
    }

    private func save() {
        #if canImport(UIKit)
        guard let data = imageData else { return }
        saveState = .saving
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in saveState = .failed }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, data: data, options: nil)
            } completionHandler: { ok, _ in
                Task { @MainActor in saveState = ok ? .saved : .failed }
            }
        }
        #endif
    }

    /// Write the JPEG to a temp file so ShareLink can share a real image file.
    private func shareURL(_ data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreeID-\(spec.id).jpg")
        try? data.write(to: url)
        return url
    }
}
