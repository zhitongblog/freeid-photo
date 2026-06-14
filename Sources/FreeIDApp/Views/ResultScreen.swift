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
                Label(zhEn("已按规格生成，可直接使用", "Ready to use — sized to spec"), systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(.green)
                Text("\(spec.displayName.text(forLanguage: localeCode)) · \(spec.pixelWidth)×\(spec.pixelHeight)px")
                    .font(.caption).foregroundStyle(.secondary)

                if model.canChooseBackground {
                    backgroundPicker
                } else {
                    Label(zhEn("该国要求原图，未替换背景，请用纯色背景拍摄",
                               "This country requires an unedited photo — use a real plain backdrop."),
                          systemImage: "exclamationmark.shield")
                        .font(.caption).foregroundStyle(.orange)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                Spacer(minLength: 8)
                saveButton
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Label(zhEn("重拍", "Retake"), systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    if let data = imageData {
                        ShareLink(item: shareURL(data)) {
                            Label(zhEn("分享", "Share"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle(zhEn("你的证件照", "Your photo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(zhEn("完成", "Done")) { dismiss() }
                }
            }
        }
    }

    /// Row of background color swatches; tapping re-exports the shot in that color.
    private var backgroundPicker: some View {
        VStack(spacing: 8) {
            Text(zhEn("背景颜色", "Background")).font(.caption).foregroundStyle(.secondary)
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
                    .accessibilityLabel(choice.name.text(forLanguage: localeCode))
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
        case .idle: return zhEn("保存到相册", "Save to Photos")
        case .saving: return zhEn("保存中…", "Saving…")
        case .saved: return zhEn("已保存", "Saved")
        case .failed: return zhEn("再试一次", "Try again")
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
