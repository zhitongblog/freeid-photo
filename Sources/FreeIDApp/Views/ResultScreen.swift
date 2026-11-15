import SwiftUI
import FreeIDCore
#if canImport(UIKit)
import UIKit
import Photos
#endif

/// Shows the finished spec-sized photo, lets the user switch specs on the fly, pick a
/// background color or gently adjust brightness & skin texture (on edit-allowed specs), and
/// save, share, or tile onto a print sheet.
struct ResultScreen: View {
    @Bindable var model: CaptureViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var saveState: SaveState = .idle
    @State private var showingPrintSheet = false
    @State private var showingSpecSwitcher = false

    enum SaveState { case idle, saving, saved, failed }

    private var spec: PhotoSpec { model.selectedSpec }
    private var imageData: Data? { model.exportedData }
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
                            VStack(spacing: 14) {
                                photoPreview(maxHeight: min(340, max(190, geo.size.height * 0.40)))
                                    .padding(.top, 6)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSpecSwitcher = true
                    } label: {
                        Label(S.switchSpec.t, systemImage: "rectangle.2.swap")
                            .font(.subheadline)
                    }
                }
            }
            .sheet(isPresented: $showingPrintSheet) { PrintSheetView(model: model) }
            .sheet(isPresented: $showingSpecSwitcher) {
                SpecPickerView(model: model, isPresented: $showingSpecSwitcher)
            }
            .onChange(of: model.exportedData) { _, _ in
                if saveState == .saved { saveState = .idle }
            }
            #if DEBUG
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
        if model.importIssues.isEmpty {
            Label(S.readyToUse.t, systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundStyle(.green)
        }

        Button {
            showingSpecSwitcher = true
        } label: {
            HStack(spacing: 5) {
                Text(specMetadataSummary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.secondary.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)

        if !model.importIssues.isEmpty { issuesCard }

        if model.canChooseBackground {
            backgroundPicker
        } else if model.backgroundLockedToSpec {
            Label(String(format: S.requiredBgNote.t, bgName), systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
        } else {
            Label(String(format: S.strictBgWarning.t, bgName), systemImage: "exclamationmark.shield")
                .font(.caption).foregroundStyle(.orange)
                .multilineTextAlignment(.center).padding(.horizontal)
        }

        if model.canRetouchPortrait {
            adjustmentsCard
        }
    }

    private var adjustmentsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sun.max")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(S.brightnessLabel.t)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 68, alignment: .leading)
                Slider(value: $model.brightnessBoost, in: -0.20...0.20, step: 0.02) {
                    Text(S.brightnessLabel.t)
                } onEditingChanged: { editing in
                    if !editing { model.reexportCurrent() }
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(S.smoothingLabel.t)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 68, alignment: .leading)
                Slider(value: $model.skinSmoothing, in: 0.0...1.0, step: 0.05) {
                    Text(S.smoothingLabel.t)
                } onEditingChanged: { editing in
                    if !editing { model.reexportCurrent() }
                }
            }
            if model.hasActiveAdjustments {
                HStack {
                    Spacer()
                    Button(S.resetAdjustments.t) {
                        model.resetAdjustments()
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
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

    private var backgroundPicker: some View {
        VStack(spacing: 8) {
            Text(S.backgroundLabel.t).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                ForEach(CaptureViewModel.BackgroundChoice.all) { choice in
                    let selected = model.backgroundHex.uppercased() == choice.hex.uppercased()
                    Button {
                        if saveState == .saved { saveState = .idle }
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

    private func shareURL(_ data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreeID-\(spec.id).jpg")
        try? data.write(to: url)
        return url
    }
}
