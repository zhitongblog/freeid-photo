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
                Label(zhEn("已按规格生成，可直接使用", "Ready to use — sized to spec"), systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(.green)
                Text(spec.displayName.text(forLanguage: localeCode))
                    .font(.subheadline)
                Text("\(spec.pixelWidth) × \(spec.pixelHeight) px · \(Int(spec.outputSize.widthMM))×\(Int(spec.outputSize.heightMM)) mm · \(spec.dpi) dpi")
                    .font(.caption).foregroundStyle(.secondary)
                if spec.digitalEditPolicy == .strict {
                    Label(zhEn("该国要求原图，未替换背景，请用纯色背景拍摄",
                               "This country requires an unedited photo — background was not replaced."),
                          systemImage: "exclamationmark.shield")
                        .font(.caption).foregroundStyle(.orange)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
                Spacer()
                saveButton
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Label(zhEn("重拍", "Retake"), systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    ShareLink(item: shareURL()) {
                        Label(zhEn("分享", "Share"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
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
        case .idle: return zhEn("保存到相册", "Save to Photos")
        case .saving: return zhEn("保存中…", "Saving…")
        case .saved: return zhEn("已保存", "Saved")
        case .failed: return zhEn("再试一次", "Try again")
        }
    }

    private func zhEn(_ zh: String, _ en: String) -> String {
        localeCode.hasPrefix("zh") ? zh : en
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
