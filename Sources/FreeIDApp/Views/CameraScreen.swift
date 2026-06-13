import SwiftUI
import FreeIDCore

/// The capture screen: live camera, a guide frame sized to the spec aspect ratio, the
/// live compliance HUD, and a shutter that unlocks only when every check is green.
struct CameraScreen: View {
    @Bindable var model: CaptureViewModel
    @Binding var showingSpecPicker: Bool

    var body: some View {
        ZStack {
            CameraPreview(controller: model.camera)
                .ignoresSafeArea()

            GuideFrame(aspectRatio: model.selectedSpec.aspectRatio)
                .ignoresSafeArea(edges: .horizontal)

            VStack {
                Spacer()
                ComplianceHUD(report: model.liveReport, languageCode: localeCode)
                    .padding(.horizontal)
                ShutterButton(enabled: model.isLiveCompliant && !model.isCapturing) {
                    model.capture()
                }
                .padding(.bottom, 24)
            }

            if model.isCapturing {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.5)
            }
        }
        .onAppear { model.camera.start() }
        .onDisappear { model.camera.stop() }
        .fullScreenCover(isPresented: $model.showResult) {
            if let data = model.exportedData {
                ResultScreen(imageData: data, spec: model.selectedSpec)
            }
        }
        .alert("Capture failed", isPresented: .init(
            get: { model.captureError != nil },
            set: { if !$0 { model.captureError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.captureError ?? "")
        }
    }
}

/// A translucent oval/rect guide showing where the head should sit, sized to the spec.
private struct GuideFrame: View {
    let aspectRatio: Double
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.7
            let h = w / aspectRatio
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .frame(width: w, height: h)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
        }
    }
}

private struct ShutterButton: View {
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(enabled ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 72, height: 72)
                Image(systemName: enabled ? "checkmark" : "camera.fill")
                    .font(.title).foregroundStyle(.white)
            }
        }
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }
}
