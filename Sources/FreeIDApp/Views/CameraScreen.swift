import SwiftUI
import FreeIDCore

/// The capture screen: live camera, a head-and-shoulders silhouette guide sized to the
/// spec, a one-line live coach, and a classic shutter that's always tappable once a face
/// is in frame. Capturing is never gated on a perfect score — the export pipeline reframes
/// and cleans up the shot, so the job here is just "get your face in the outline."
struct CameraScreen: View {
    @Bindable var model: CaptureViewModel
    @Binding var showingSpecPicker: Bool

    var body: some View {
        ZStack {
            CameraPreview(controller: model.camera)
                .ignoresSafeArea()

            HeadGuide(spec: model.selectedSpec, ready: model.isLiveCompliant && model.hasFace)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                CoachLine(hint: model.liveHint)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                if model.usingBackCamera {
                    Text(S.backCameraHint.t)
                        .font(.caption).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.black.opacity(0.4), in: Capsule())
                        .padding(.bottom, 8)
                }
                ZStack {
                    ShutterButton(enabled: model.hasFace && !model.isCapturing) {
                        model.capture()
                    }
                    HStack {
                        Spacer()
                        FlipCameraButton { model.flipCamera() }
                            .padding(.trailing, 36)
                    }
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
            ResultScreen(model: model)
        }
        .alert(S.captureFailedTitle.t, isPresented: .init(
            get: { model.captureError != nil },
            set: { if !$0 { model.captureError = nil } })) {
            Button(S.ok.t, role: .cancel) {}
        } message: {
            Text(model.captureError ?? "")
        }
    }
}

/// A head-and-shoulders silhouette positioned from the real spec geometry: fill the outline
/// and the exported crop lands at the spec's head size and eye height. Turns green when the
/// shot is good. This is the "人头框" consumer ID-photo apps use — not a bare rectangle.
private struct HeadGuide: View {
    let spec: PhotoSpec
    let ready: Bool

    var body: some View {
        GeometryReader { geo in
            // The photo frame: the exported photo's proportions (spec aspect ratio).
            let frameW = min(geo.size.width * 0.80, geo.size.height * 0.62 * spec.aspectRatio)
            let frameH = frameW / spec.aspectRatio
            let frame = CGRect(x: (geo.size.width - frameW) / 2,
                               y: geo.size.height * 0.44 - frameH / 2,
                               width: frameW, height: frameH)

            // Head sized + placed inside the frame from the spec (head height + eye line).
            let headFrac = spec.headHeight.mid / spec.outputSize.heightMM
            let eyeFromBottom = spec.eyeLineFromBottom.mid / spec.outputSize.heightMM
            let headH = frameH * headFrac
            let headW = headH * 0.74
            let eyeY = frame.maxY - frameH * eyeFromBottom
            let headCenterY = eyeY - headH * 0.46 + headH / 2   // eyes sit ~46% below the crown
            let headRect = CGRect(x: frame.midX - headW / 2, y: headCenterY - headH / 2,
                                  width: headW, height: headH)

            ZStack {
                // Dim everything outside the photo frame so the real crop is obvious.
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: geo.size))
                    p.addRoundedRect(in: frame, cornerSize: CGSize(width: 16, height: 16))
                }
                .fill(.black.opacity(0.5), style: FillStyle(eoFill: true))

                // Head + shoulders outline.
                ZStack {
                    Ellipse()
                        .stroke(guideColor, style: dash)
                        .frame(width: headW, height: headH)
                        .position(x: headRect.midX, y: headRect.midY)
                    Shoulders(headRect: headRect, frame: frame).stroke(guideColor, style: dash)
                }

                // Photo frame border.
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.85), lineWidth: 2)
                    .frame(width: frameW, height: frameH)
                    .position(x: frame.midX, y: frame.midY)
            }
            .animation(.easeInOut(duration: 0.25), value: ready)
        }
    }

    private var guideColor: Color { ready ? .green : .white.opacity(0.9) }
    private var dash: StrokeStyle { StrokeStyle(lineWidth: 3, lineCap: .round, dash: [11, 9]) }
}

/// Two shoulder curves sweeping from the neck down to the bottom corners of the frame.
private struct Shoulders: Shape {
    let headRect: CGRect
    let frame: CGRect
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let neckY = headRect.maxY - headRect.height * 0.02
        let bottom = frame.maxY
        let leftNeck = CGPoint(x: headRect.midX - headRect.width * 0.30, y: neckY)
        let rightNeck = CGPoint(x: headRect.midX + headRect.width * 0.30, y: neckY)
        p.move(to: leftNeck)
        p.addQuadCurve(to: CGPoint(x: frame.minX + frame.width * 0.06, y: bottom),
                       control: CGPoint(x: headRect.midX - headRect.width * 0.95, y: bottom))
        p.move(to: rightNeck)
        p.addQuadCurve(to: CGPoint(x: frame.maxX - frame.width * 0.06, y: bottom),
                       control: CGPoint(x: headRect.midX + headRect.width * 0.95, y: bottom))
        return p
    }
}

/// One friendly coaching line above the shutter. Green and reassuring when ready; a single
/// gentle nudge otherwise — never a list, never a red wall.
private struct CoachLine: View {
    let hint: CaptureViewModel.CaptureHint
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.headline)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.black.opacity(0.5), in: Capsule())
    }

    private var color: Color { hint == .ready ? .green : .white }
    private var icon: String {
        switch hint {
        case .ready: return "checkmark.circle.fill"
        case .findFace, .onePerson: return "viewfinder"
        case .straighten: return "person.crop.rectangle"
        case .moveCloser: return "arrow.up.left.and.arrow.down.right"
        case .moveBack: return "arrow.down.right.and.arrow.up.left"
        }
    }
    private var text: String {
        switch hint {
        case .ready:     return S.coachReady.t
        case .findFace:  return S.coachFindFace.t
        case .onePerson: return S.coachOnePerson.t
        case .straighten:return S.coachStraighten.t
        case .moveCloser:return S.coachCloser.t
        case .moveBack:  return S.coachBack.t
        }
    }
}

/// Flip between the selfie camera and the back camera (so a friend can take the photo).
private struct FlipCameraButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                .font(.title2).foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.4), in: Circle())
        }
        .accessibilityLabel(S.switchCamera.t)
    }
}

/// Classic camera shutter — a big white capture button. Tappable whenever a face is in
/// frame; capturing is never blocked on a perfect compliance score.
private struct ShutterButton: View {
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(.white.opacity(enabled ? 0.95 : 0.4), lineWidth: 4)
                    .frame(width: 78, height: 78)
                Circle().fill(enabled ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 64, height: 64)
            }
        }
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }
}
