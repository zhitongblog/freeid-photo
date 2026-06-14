import SwiftUI
import FreeIDCore

struct ContentView: View {
    @State private var model = CaptureViewModel()
    @State private var showingSpecPicker = false

    var body: some View {
        NavigationStack {
            CameraScreen(model: model, showingSpecPicker: $showingSpecPicker)
                .navigationTitle("FreeID Photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSpecPicker = true
                        } label: {
                            Label(model.selectedSpec.displayName.text(forLanguage: localeCode),
                                  systemImage: "globe")
                        }
                    }
                }
                .sheet(isPresented: $showingSpecPicker) {
                    SpecPickerView(model: model, isPresented: $showingSpecPicker)
                }
        }
    }
}

/// Two-letter UI language code, used to pick the localized text in specs.
var localeCode: String { String(Locale.preferredLanguages.first?.prefix(2) ?? "en") }

/// Pick Chinese or English UI copy based on the device language.
func zhEn(_ zh: String, _ en: String) -> String { localeCode.hasPrefix("zh") ? zh : en }

extension Color {
    /// Build a SwiftUI Color from a "#RRGGBB" string (reuses the core color parser).
    init(hex: String) {
        guard let rgb = ColorMath.rgb(fromHex: hex) else { self = .white; return }
        self = Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
