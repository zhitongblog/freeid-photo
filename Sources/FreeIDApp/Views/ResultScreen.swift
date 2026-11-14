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
    @State private var showingPrintSheet = false

    enum SaveState { case idle, saving, saved, failed }

    private var spec: PhotoSpec { model.selectedSpec }
    private var imageData: Data? { model.exportedData }
    /// The spec's required background color name, localized, e.g. "白色" / "white".
    private var bgName: String { SpecText.colorName(spec.background.hex) }

    private var specMetadataSummary: String {
        var parts = [
            SpecText.name(spec),
            "\(spec.pixelWidth)×\(spec.pixelHeight)px",
            "\(spec.dpi)dpi",
        ]
        if let bytes = imageData?.count, bytes > 0 {
            parts.append("\(max(1, (bytes + 512) / 1024)) KB")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let isWide = geo.size.width > 560 && geo.size.width > geo.size.height * 0.85
                Group {
                    if isWide {
                        HStack(alignment: .center, spacing: 28) {
                            photoPreview(maxHeight: max(200, geo.size.height - 48))
                                .frame(maxWidth: geo.size.width * 0.46)
                            ScrollView {
                                VStack(spacing: 16) {
                                    detailsSection
                                    actionsSection
                                }
                                .padding(.vertical, 16)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                photoPreview(maxHeight: min(360, max(200, geo.size.height * 0.45)))
                                    .padding(.top, 8)
                                detailsSection
                                actionsSection
                            }
                            .frame(minHeight: geo.size.height)
                        }
                    }
                }
            }
            .navigationTitle(S.yourPhoto.t)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(S.done.t) { dismiss() }
                }
            }
            .sheet(isPresented: $showingPrintSheet) { PrintSheetView(model: model) }
            #if DEBUG
            // Harness: `-show-print-sheet` opens the sheet without a tap, so the screen can be
            // driven where UI automation isn't available.
            .task {
                if ProcessInfo.processInfo.arguments.contains("-show-print-sheet") {
                    showingPrintSheet = true
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func photoPreview(maxHeight: CGFloat) -> some View {
        #if canImport(UIKit)
        if let data = imageData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable().scaledToFit()
                .frame(maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 8)
        }
        #endif
    }

    @ViewBuilder
    private var detailsSection: some View {
        // Don't claim "ready to use" over a list of unmet requirements — the card
        // below says what's wrong, so the headline stays honest and steps aside.
        if model.importIssues.isEmpty {
            Label(S.readyToUse.t, systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundStyle(.green)
        }
        Text(specMetadataSummary)
            .font(.caption).foregroundStyle(.secondary)

        if !model.importIssues.isEmpty { issuesCard }

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
    }

    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: 12) {
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

            Button { showingPrintSheet = true } label: {
                Label(S.printSheet.t, systemImage: "printer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(imageData == nil)
            .padding(.horizontal)

            Link(destination: Brand.url) {
                HStack(spacing: 0) {
                    Text(Brand.creditPrefix.t)
                    BrandWordmark(size: 13)
                    Text(Brand.creditSuffix.t)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    /// What this photo still doesn't satisfy. Only shown for photos picked from the library —
    /// a live capture was already coached in the viewfinder. Advisory, never blocking: the
    /// photo is saved either way, and the user is the one who knows what it's for.
    private var issuesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(S.checkBeforeYouSubmit.t, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
            ForEach(Array(model.importIssues.enumerated()), id: \.offset) { _, issue in
                Text("• " + issue.t).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
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
        guard let data = imageData else { return }
        saveState = .saving
        PhotoLibrarySaver.save(data) { ok in
            Task { @MainActor in saveState = ok ? .saved : .failed }
        }
    }

    /// Write the JPEG to a temp file so ShareLink can share a real image file.
    private func shareURL(_ data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreeID-\(spec.id).jpg")
        try? data.write(to: url)
        return url
    }
}
