import SwiftUI
import FreeIDCore

/// Pick a country + document type. Specs are grouped by country; selecting one updates
/// the live viewfinder's target immediately.
struct SpecPickerView: View {
    @Bindable var model: CaptureViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.specsGroupedByCountry(), id: \.country) { group in
                    Section(group.country) {
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
            }
            .navigationTitle("Choose document")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private func row(_ spec: PhotoSpec) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(spec.displayName.text(forLanguage: localeCode))
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
