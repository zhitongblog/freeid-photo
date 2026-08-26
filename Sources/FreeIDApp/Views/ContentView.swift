import SwiftUI
import FreeIDCore

struct ContentView: View {
    @State private var model = CaptureViewModel()
    @State private var showingSpecPicker = false
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            CameraScreen(model: model, showingSpecPicker: $showingSpecPicker)
                .navigationTitle("FreeID Photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingAbout = true } label: {
                            BrandWordmark(size: 17, base: .white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.black.opacity(0.45), in: Capsule())
                        }
                        .accessibilityLabel("doaipm")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSpecPicker = true
                        } label: {
                            Label(SpecText.name(model.selectedSpec), systemImage: "globe")
                        }
                    }
                }
                .sheet(isPresented: $showingSpecPicker) {
                    SpecPickerView(model: model, isPresented: $showingSpecPicker)
                }
                .sheet(isPresented: $showingAbout) {
                    AboutView()
                }
                #if DEBUG
                .task { model.runImportLaunchHookIfRequested() }
                #endif
        }
    }
}

extension Color {
    /// Build a SwiftUI Color from a "#RRGGBB" string (reuses the core color parser).
    init(hex: String) {
        guard let rgb = ColorMath.rgb(fromHex: hex) else { self = .white; return }
        self = Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
