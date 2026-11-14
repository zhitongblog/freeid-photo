import SwiftUI
import FreeIDCore

/// Pick a country + document type, search by keyword/dimensions, or enter a custom size
/// with optional file-size (KB) limit. Selecting one updates the live viewfinder immediately.
struct SpecPickerView: View {
    @Bindable var model: CaptureViewModel
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var customWidthMM = "25"
    @State private var customHeightMM = "35"
    @State private var customMaxKB = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups, id: \.country) { group in
                    Section(SpecText.country(group.country).t) {
                        ForEach(group.specs) { spec in
                            Button {
                                model.selectedSpec = spec
                                isPresented = false
                            } label: {
                                row(spec)
                            }
                        }
                    }
                }

                Section(S.customSize.t) {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(S.widthMM.t).font(.caption).foregroundStyle(.secondary)
                                TextField("25", text: $customWidthMM)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(S.heightMM.t).font(.caption).foregroundStyle(.secondary)
                                TextField("35", text: $customHeightMM)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(S.maxKBLabel.t).font(.caption).foregroundStyle(.secondary)
                                TextField("100", text: $customMaxKB)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        Button {
                            applyCustomSpec()
                        } label: {
                            Text(S.useCustomSize.t)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isCustomValid)
                    }
                    .padding(.vertical, 4)
                }
            }
            .searchable(text: $query, prompt: S.searchSpecs.t)
            .navigationTitle(S.chooseDoc.t)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(S.cancel.t) { isPresented = false }
                }
            }
        }
    }

    private var isCustomValid: Bool {
        guard let w = Double(customWidthMM), let h = Double(customHeightMM) else { return false }
        return w >= 10 && w <= 120 && h >= 10 && h <= 160
    }

    private func applyCustomSpec() {
        guard let w = Double(customWidthMM), let h = Double(customHeightMM) else { return }
        let maxKB = Int(customMaxKB.trimmingCharacters(in: .whitespaces))
        let validMaxKB = (maxKB != nil && maxKB! >= 10) ? maxKB : nil
        model.selectedSpec = PhotoSpec.custom(widthMM: w, heightMM: h, maxKB: validMaxKB)
        isPresented = false
    }

    private var filteredGroups: [(country: String, specs: [PhotoSpec])] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return model.specsGroupedByCountry() }
        return model.specsGroupedByCountry().compactMap { group in
            let countryMatch = SpecText.country(group.country).t.lowercased().contains(q)
                || group.country.lowercased().contains(q)
            let matches = group.specs.filter { spec in
                if countryMatch { return true }
                let hay = [
                    spec.id,
                    spec.displayName.en,
                    spec.displayName.zh,
                    SpecText.name(spec),
                    "\(Int(spec.outputSize.widthMM))x\(Int(spec.outputSize.heightMM))",
                    "\(Int(spec.outputSize.widthMM))×\(Int(spec.outputSize.heightMM))",
                    "\(spec.pixelWidth)x\(spec.pixelHeight)",
                ].joined(separator: " ").lowercased()
                return hay.contains(q)
            }
            return matches.isEmpty ? nil : (group.country, matches)
        }
    }

    private func row(_ spec: PhotoSpec) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(SpecText.name(spec))
                    .font(.body).foregroundStyle(.primary)
                Text("\(Int(spec.outputSize.widthMM))×\(Int(spec.outputSize.heightMM))mm · "
                     + "\(spec.pixelWidth)×\(spec.pixelHeight)px")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if spec.id == model.selectedSpec.id {
                Image(systemName: "checkmark").foregroundStyle(.tint)
            }
        }
    }
}
