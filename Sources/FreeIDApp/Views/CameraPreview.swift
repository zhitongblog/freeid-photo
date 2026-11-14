import SwiftUI
#if os(iOS)
import UIKit
import AVFoundation

/// Hosts the AVCaptureVideoPreviewLayer. Shows the live camera feed behind the HUD.
struct CameraPreview: UIViewRepresentable {
    let controller: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = controller.session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        controller.attachPreviewLayer(v.videoPreviewLayer)
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        controller.attachPreviewLayer(uiView.videoPreviewLayer)
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
#else
struct CameraPreview: View {
    let controller: CameraController
    var body: some View { Color.black }
}
#endif
