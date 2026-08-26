import SwiftUI
import FreeIDCore
#if canImport(UIKit)
import UIKit
import Photos
#endif

/// Writes JPEG bytes into the user's photo library. Shared by the single photo and the
/// print sheet so both report identical states.
enum PhotoLibrarySaver {
    static func save(_ data: Data, completion: @escaping @Sendable (Bool) -> Void) {
        #if canImport(UIKit)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { completion(false); return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            } completionHandler: { ok, _ in completion(ok) }
        }
        #else
        completion(false)
        #endif
    }
}

/// Lays copies of the finished photo onto one sheet of photo paper.
///
/// The cheapest way to get physical ID photos is to hand a print counter (or your own
/// printer) a single correctly-sized file with as many copies as fit — that is what this
/// produces. The sheet carries the spec's DPI so the lab prints it at true size.
struct PrintSheetView: View {
    @Bindable var model: CaptureViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var paper: ExportPipeline.PrintPaper = .fourBySix
    @State private var sheetData: Data?
    @State private var isRendering = false
    @State private var saveState: ResultScreen.SaveState = .idle
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("", selection: $paper) {
                    ForEach(ExportPipeline.PrintPaper.allCases, id: \.self) { p in
                        Text(label(for: p)).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Text(S.printSheetNote.t)
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)

                ZStack {
                    #if canImport(UIKit)
                    if let data = sheetData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(radius: 6)
                    }
                    #endif
                    if isRendering { ProgressView() }
                    if failed && !isRendering {
                        Text(S.sheetFailed.t).font(.callout).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 340)
                .padding(.horizontal)

                Spacer(minLength: 0)

                Button { saveSheet() } label: {
                    Label(saveLabel, systemImage: saveState == .saved ? "checkmark" : "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(sheetData == nil || saveState == .saving || saveState == .saved)
                .padding(.horizontal)

                if let data = sheetData {
                    ShareLink(item: shareURL(data)) {
                        Label(S.share.t, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .navigationTitle(S.printSheet.t)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(S.done.t) { dismiss() } }
            }
        }
        .onAppear { render() }
        .onChange(of: paper) { _, _ in render() }
    }

    /// "4×6″ · 6 copies" — the copy count is the number people actually choose on.
    private func label(for p: ExportPipeline.PrintPaper) -> String {
        let name: String
        switch p {
        case .fourBySix:   name = "4×6″"
        case .fiveBySeven: name = "5×7″"
        case .a4:          name = "A4"
        }
        return name + " · " + String(format: S.copiesFormat.t, model.copies(on: p))
    }

    private func render() {
        isRendering = true
        failed = false
        saveState = .idle
        sheetData = nil
        model.makePrintSheet(paper: paper) { data in
            Task { @MainActor in
                isRendering = false
                sheetData = data
                failed = (data == nil)
            }
        }
    }

    private var saveLabel: String {
        switch saveState {
        case .idle: return S.saveToPhotos.t
        case .saving: return S.saving.t
        case .saved: return S.saved.t
        case .failed: return S.tryAgain.t
        }
    }

    private func saveSheet() {
        guard let data = sheetData else { return }
        saveState = .saving
        PhotoLibrarySaver.save(data) { ok in
            Task { @MainActor in saveState = ok ? .saved : .failed }
        }
    }

    private func shareURL(_ data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreeID-\(model.selectedSpec.id)-sheet.jpg")
        try? data.write(to: url)
        return url
    }
}
