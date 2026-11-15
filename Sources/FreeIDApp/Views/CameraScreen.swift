import SwiftUI
import PhotosUI
import FreeIDCore

/// The capture screen: live camera, a head-and-shoulders silhouette guide sized to the
/// spec, a one-line live coach, and a classic shutter that's always tappable once a face
/// is in frame. Capturing is never gated on a perfect score — the export pipeline reframes
/// and cleans up the shot, so the job here is just "get your face in the outline."
struct CameraScreen: View {
    @Bindable var model: CaptureViewModel
    @Binding var showingSpecPicker: Bool
    /// The photo picked from the library, if the user went that route instead of shooting.
    @State private var pickedItem: PhotosPickerItem?
    @State private var showingHistory = false

    var body: some View {
        ZStack {
            CameraPreview(controller: model.camera)
                .ignoresSafeArea()

            HeadGuide(spec: model.selectedSpec, ready: model.isLiveCompliant && model.hasFace)
                .ignoresSafeArea()

            // Reminder to step back and include shoulders — ID photos are head-and-shoulders,
            // and a too-close selfie crops them out before the export can keep them.
            VStack {
                Text(S.includeShoulders.t)
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(.top, 8)
                Spacer()
            }

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
                        HStack(spacing: 12) {
                            // Not everyone can be shot live — a baby won't hold a pose, and plenty
                            // of people already have the photo they want to use.
                            PhotosPicker(selection: $pickedItem, matching: .images,
                                         photoLibrary: .shared()) {
                                LibraryButtonLabel()
                            }
                            if !model.historyEntries.isEmpty {
                                Button {
                                    showingHistory = true
                                } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.title3).foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(.black.opacity(0.45), in: Circle())
                                }
                                .accessibilityLabel(S.historyTitle.t)
                            }
                        }
                        .padding(.leading, 24)
                        Spacer()
                        FlipCameraButton { model.flipCamera() }
                            .padding(.trailing, 36)
                    }
                }
                .padding(.bottom, 24)
            }

            if model.isCapturing || model.isImporting {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().tint(.white).scaleEffect(1.5)
                    if model.isImporting {
                        Text(S.importing.t).font(.subheadline).foregroundStyle(.white)
                    }
                }
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                // Load the original bytes (not a UIImage) so the EXIF orientation tag survives
                // to ImageLoading — a re-encoded UIImage would arrive stripped and sideways.
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.importPhoto(data)
                } else {
                    model.captureError = S.importUnreadable.t
                }
                pickedItem = nil
            }
        }
        .onAppear { model.camera.start() }
        .onDisappear { model.camera.stop() }
        .fullScreenCover(isPresented: $model.showResult) {
            ResultScreen(model: model)
        }
        .sheet(isPresented: $showingHistory) {
            HistorySheetView(model: model)
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
            // Reserve top space for the navigation bar + reminder pill, and bottom space for
            // the coach pill + shutter row, so unfolding an iPhone Duo or rotating to a wide /
            // short container never lets the guide frame collide with the controls.
            let topReserved = max(geo.safeAreaInsets.top + 52, geo.size.height * 0.12)
            let bottomReserved = max(geo.safeAreaInsets.bottom + 148, geo.size.height * 0.24)
            let availH = max(120, geo.size.height - topReserved - bottomReserved)
            let availW = max(120, geo.size.width * 0.80)

            // The photo frame: the exported photo's proportions (spec aspect ratio).
            let frameW = min(availW, availH * spec.aspectRatio)
            let frameH = frameW / spec.aspectRatio
            let centerY = topReserved + availH / 2
            let frame = CGRect(x: (geo.size.width - frameW) / 2,
                               y: centerY - frameH / 2,
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

                // Faint head + shoulders fill so it reads instantly as a person — and makes
                // it obvious that shoulders belong in the shot (these are head-and-shoulders
                // photos; China passport etc. require the shoulders visible).
                ZStack {
                    Ellipse().frame(width: headW, height: headH).position(x: headRect.midX, y: headRect.midY)
                    Torso(headRect: headRect, frame: frame)
                }
                .foregroundStyle(guideColor.opacity(ready ? 0.18 : 0.12))

                // Head + shoulders dashed outline.
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

/// Geometry shared by the shoulder outline and torso fill.
private enum Bust {
    static func neckHalf(_ h: CGRect) -> CGFloat { h.width * 0.24 }
    static func neckY(_ h: CGRect) -> CGFloat { h.maxY - h.height * 0.02 }
    static func inset(_ f: CGRect) -> CGFloat { f.width * 0.05 }
}

/// Two rounded shoulder curves sweeping from the neck out to the bottom corners — a real
/// head-and-shoulders bust, not thin lines, so "include your shoulders" reads at a glance.
private struct Shoulders: Shape {
    let headRect: CGRect
    let frame: CGRect
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let nh = Bust.neckHalf(headRect), ny = Bust.neckY(headRect)
        let bottom = frame.maxY, drop = bottom - ny
        let lx = frame.minX + Bust.inset(frame), rx = frame.maxX - Bust.inset(frame)
        p.move(to: CGPoint(x: headRect.midX - nh, y: ny))
        p.addCurve(to: CGPoint(x: lx, y: bottom),
                   control1: CGPoint(x: headRect.midX - nh, y: ny + drop * 0.42),
                   control2: CGPoint(x: lx, y: bottom - drop * 0.55))
        p.move(to: CGPoint(x: headRect.midX + nh, y: ny))
        p.addCurve(to: CGPoint(x: rx, y: bottom),
                   control1: CGPoint(x: headRect.midX + nh, y: ny + drop * 0.42),
                   control2: CGPoint(x: rx, y: bottom - drop * 0.55))
        return p
    }
}

/// Closed torso (shoulders + neck + bottom) for the faint silhouette fill; the cross-neck
/// edge sits just inside the head ellipse, so it's hidden under the head fill.
private struct Torso: Shape {
    let headRect: CGRect
    let frame: CGRect
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let nh = Bust.neckHalf(headRect), ny = Bust.neckY(headRect)
        let bottom = frame.maxY, drop = bottom - ny
        let lx = frame.minX + Bust.inset(frame), rx = frame.maxX - Bust.inset(frame)
        p.move(to: CGPoint(x: lx, y: bottom))
        p.addCurve(to: CGPoint(x: headRect.midX - nh, y: ny),
                   control1: CGPoint(x: lx, y: bottom - drop * 0.55),
                   control2: CGPoint(x: headRect.midX - nh, y: ny + drop * 0.42))
        p.addLine(to: CGPoint(x: headRect.midX + nh, y: ny))
        p.addCurve(to: CGPoint(x: rx, y: bottom),
                   control1: CGPoint(x: headRect.midX + nh, y: ny + drop * 0.42),
                   control2: CGPoint(x: rx, y: bottom - drop * 0.55))
        p.closeSubpath()
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
/// The photo-library affordance next to the shutter. Mirrors `FlipCameraButton`'s weight so
/// neither reads as the primary action — the shutter still is.
private struct LibraryButtonLabel: View {
    var body: some View {
        Image(systemName: "photo.on.rectangle")
            .font(.title2).foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.black.opacity(0.45), in: Circle())
            .accessibilityLabel(S.choosePhoto.t)
    }
}

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
