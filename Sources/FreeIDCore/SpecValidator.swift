import Foundation

/// Pose and quality tolerances that aren't expressed per-spec. Defaults are
/// conservative values common to ICAO 9303-derived requirements; a spec-specific
/// override can be threaded through later if any country diverges.
public struct ValidationTolerances: Sendable {
    // Generous, forgiving pose limits — a slight natural tilt should not lock the shutter.
    public var maxRollDegrees: Double = 10
    public var maxYawDegrees: Double = 14
    public var maxPitchDegrees: Double = 14
    /// Max allowed |faceCenterX - 0.5|.
    public var maxCenterOffset: Double = 0.06
    public var minBrightness: Double = 0.35
    public var maxBrightness: Double = 0.92
    /// Minimum allowed left-vs-right cheek lighting symmetry (0..1). Below ~0.60 indicates a
    /// strong side shadow ("阴阳脸").
    public var minLightingUniformity: Double = 0.60
    public init() {}
}

/// Validates a FaceMetrics against a PhotoSpec and produces a ComplianceReport.
///
/// Pure logic: no Vision, no images, no I/O. The metrics are assumed to be measured
/// on an image already framed to the spec's aspect ratio (both the live viewfinder
/// guide and the export crop enforce that), so head/eye fractions map straight to mm
/// via the spec's output height.
///
///   measured fraction (0..1) × outputSize.heightMM = measured millimetres
///   → compared against the spec's allowed RangeMM
public enum SpecValidator {

    public static func validate(
        _ m: FaceMetrics,
        against spec: PhotoSpec,
        tolerances t: ValidationTolerances = .init()
    ) -> ComplianceReport {
        var checks: [CheckResult] = []

        // 1. Exactly one face.
        checks.append(faceCountCheck(m))

        // 2. Head height (chin-to-crown) in mm.
        let headMM = m.headFraction * spec.outputSize.heightMM
        checks.append(rangeCheck(
            id: "headHeight",
            title: LocalizedText(en: "Head height", zh: "头部高度"),
            value: headMM, range: spec.headHeight, unit: "mm"
        ))

        // 3. Eye line distance from bottom edge in mm.
        let eyeMM = m.eyeFromBottomFraction * spec.outputSize.heightMM
        checks.append(rangeCheck(
            id: "eyeLine",
            title: LocalizedText(en: "Eye position", zh: "眼睛位置"),
            value: eyeMM, range: spec.eyeLineFromBottom, unit: "mm"
        ))

        // 4. Horizontal centering.
        let offset = abs(m.faceCenterX - 0.5)
        checks.append(boolCheck(
            id: "centering",
            title: LocalizedText(en: "Centering", zh: "居中"),
            ok: offset <= t.maxCenterOffset,
            okDetail: LocalizedText(en: "Face is centered", zh: "面部居中"),
            failDetail: LocalizedText(en: "Move face to horizontal center", zh: "请将面部移到水平中央")
        ))

        // 5. Pose (roll / yaw / pitch).
        let poseOK = abs(m.rollDegrees) <= t.maxRollDegrees
            && abs(m.yawDegrees) <= t.maxYawDegrees
            && abs(m.pitchDegrees) <= t.maxPitchDegrees
        checks.append(boolCheck(
            id: "pose",
            title: LocalizedText(en: "Head straight", zh: "头部端正"),
            ok: poseOK,
            okDetail: LocalizedText(en: "Head is level and facing forward", zh: "头部水平且正对镜头"),
            failDetail: LocalizedText(en: "Keep head straight, face the camera", zh: "请摆正头部，正对镜头")
        ))

        // 6. Eyes open.
        if spec.expression.eyesOpen {
            checks.append(boolCheck(
                id: "eyesOpen",
                title: LocalizedText(en: "Eyes open", zh: "睁眼"),
                ok: m.eyesOpen,
                okDetail: LocalizedText(en: "Both eyes open", zh: "双眼睁开"),
                failDetail: LocalizedText(en: "Open both eyes", zh: "请睁开双眼")
            ))
        }

        // 7. Mouth closed.
        if spec.expression.mouthClosed {
            checks.append(boolCheck(
                id: "mouthClosed",
                title: LocalizedText(en: "Mouth closed", zh: "闭嘴"),
                ok: m.mouthClosed,
                okDetail: LocalizedText(en: "Mouth closed", zh: "嘴部闭合"),
                failDetail: LocalizedText(en: "Close your mouth", zh: "请闭上嘴")
            ))
        }

        // 8. Neutral expression.
        if spec.expression.neutral {
            checks.append(boolCheck(
                id: "neutral",
                title: LocalizedText(en: "Neutral expression", zh: "表情自然"),
                ok: m.neutralExpression,
                okDetail: LocalizedText(en: "Neutral expression", zh: "表情自然"),
                failDetail: LocalizedText(en: "Use a neutral expression, don't smile", zh: "请保持自然表情，不要微笑")
            ))
        }

        // 9. Background uniformity.
        checks.append(boolCheck(
            id: "background.uniformity",
            title: LocalizedText(en: "Even background", zh: "背景均匀"),
            ok: m.backgroundUniformity >= spec.background.minUniformity,
            okDetail: LocalizedText(en: "Background is even", zh: "背景均匀无阴影"),
            failDetail: LocalizedText(en: "Use an even, shadow-free background", zh: "请使用均匀、无阴影的背景")
        ))

        // 10. Background color. In strict-edit countries a mismatch can't be auto-fixed,
        //     so it's a hard fail; in allowed countries it's a warning (export can replace it).
        let dE = ColorMath.deltaE(m.backgroundMeanHex, spec.background.hex)
        let colorOK = dE <= spec.background.toleranceDeltaE
        if colorOK {
            checks.append(CheckResult(
                id: "background.color",
                title: LocalizedText(en: "Background color", zh: "背景颜色"),
                status: .pass,
                detail: LocalizedText(en: "Background color matches", zh: "背景颜色符合要求")
            ))
        } else if spec.digitalEditPolicy == .allowed {
            checks.append(CheckResult(
                id: "background.color",
                title: LocalizedText(en: "Background color", zh: "背景颜色"),
                status: .warn,
                detail: LocalizedText(
                    en: "Background color is off; it can be replaced on export",
                    zh: "背景颜色不符，可在导出时替换"
                )
            ))
        } else {
            checks.append(CheckResult(
                id: "background.color",
                title: LocalizedText(en: "Background color", zh: "背景颜色"),
                status: .fail,
                detail: LocalizedText(
                    en: "This country forbids edited photos — use a real matching background",
                    zh: "该国不接受修图，请使用符合要求的真实背景"
                )
            ))
        }

        // 11. Exposure.
        let exposureOK = m.brightness >= t.minBrightness && m.brightness <= t.maxBrightness
        checks.append(boolCheck(
            id: "exposure",
            title: LocalizedText(en: "Lighting", zh: "光线"),
            ok: exposureOK,
            okDetail: LocalizedText(en: "Lighting is good", zh: "光线良好"),
            failDetail: m.brightness < t.minBrightness
                ? LocalizedText(en: "Too dark — add light", zh: "太暗，请增加光线")
                : LocalizedText(en: "Too bright — reduce light", zh: "太亮，请减弱光线")
        ))

        // 11b. Facial lighting balance (left vs right cheek shadow / 阴阳脸).
        checks.append(boolCheck(
            id: "faceLighting",
            title: LocalizedText(en: "Even face lighting", zh: "面部光线均匀"),
            ok: m.lightingUniformity >= t.minLightingUniformity,
            okDetail: LocalizedText(en: "Face is evenly lit", zh: "面部左右受光均匀"),
            failDetail: LocalizedText(en: "Uneven shadow across face — face the light",
                                      zh: "面部左右光线不均，请正对光源避免侧影")
        ))

        // 12. Glasses.
        switch spec.glasses {
        case .forbidden:
            checks.append(boolCheck(
                id: "glasses",
                title: LocalizedText(en: "No glasses", zh: "不戴眼镜"),
                ok: !m.glassesDetected,
                okDetail: LocalizedText(en: "No glasses", zh: "未佩戴眼镜"),
                failDetail: LocalizedText(en: "Remove your glasses", zh: "请摘下眼镜")
            ))
        case .allowedNoGlare:
            checks.append(boolCheck(
                id: "glasses",
                title: LocalizedText(en: "No glare on glasses", zh: "镜片无反光"),
                ok: !(m.glassesDetected && m.glareOnGlasses),
                okDetail: LocalizedText(en: "No glare on glasses", zh: "镜片无反光"),
                failDetail: LocalizedText(en: "Glare on glasses — tilt to remove it", zh: "镜片反光，请调整角度")
            ))
        }

        // Expression / eye / glasses detection from face landmarks & periocular heuristics is
        // kept advisory for every spec: shown so the user can self-check (especially on
        // imported photos), never locking the shutter. Reliable, decisive checks (one face,
        // pose, geometry, background color) still gate.
        checks = checks.map { c in
            guard c.status == .fail, Self.advisoryChecks.contains(c.id) else { return c }
            return CheckResult(id: c.id, title: c.title, status: .warn, detail: c.detail)
        }

        // Per-country leniency: when the destination allows digital editing, the checks
        // we can fix in the export pipeline (crop reframes head/eye/centering, background
        // replacement, exposure/lighting adjustment) should NOT block capture — they become
        // advisory warnings that get auto-corrected on export. Strict countries (US, UK...)
        // keep every check hard, because nothing may be altered after the shot.
        if spec.digitalEditPolicy == .allowed {
            checks = checks.map { c in
                guard c.status == .fail, Self.postFixableChecks.contains(c.id) else { return c }
                return CheckResult(
                    id: c.id, title: c.title, status: .warn,
                    detail: LocalizedText(en: c.detail.en + " — auto-corrected on export",
                                          zh: c.detail.zh + "（导出时自动校正）"))
            }
        }

        return ComplianceReport(specID: spec.id, checks: checks)
    }

    /// Checks the export pipeline can fix or soften after capture (crop, background replace,
    /// exposure/lighting). Downgraded from fail to warn for edit-allowed specs.
    static let postFixableChecks: Set<String> = [
        "headHeight", "eyeLine", "centering",
        "background.uniformity", "background.color", "exposure", "faceLighting",
    ]

    /// Checks driven by heuristic vision signals. Advisory for EVERY spec — shown
    /// as warnings, never blocking capture, so a false positive can't lock the shutter.
    static let advisoryChecks: Set<String> = [
        "mouthClosed", "neutral", "eyesOpen", "glasses",
    ]

    // MARK: - Check builders

    private static func faceCountCheck(_ m: FaceMetrics) -> CheckResult {
        let title = LocalizedText(en: "One person", zh: "单人")
        if m.faceCount == 1 {
            return CheckResult(id: "faceCount", title: title, status: .pass,
                detail: LocalizedText(en: "Exactly one face", zh: "画面中只有一人"))
        }
        let detail = m.faceCount == 0
            ? LocalizedText(en: "No face detected", zh: "未检测到人脸")
            : LocalizedText(en: "More than one face detected", zh: "检测到多张人脸")
        return CheckResult(id: "faceCount", title: title, status: .fail, detail: detail)
    }

    private static func rangeCheck(
        id: String, title: LocalizedText, value: Double, range: RangeMM, unit: String
    ) -> CheckResult {
        let v = (value * 10).rounded() / 10
        if range.contains(value) {
            return CheckResult(id: id, title: title, status: .pass,
                detail: LocalizedText(
                    en: "\(v)\(unit) (allowed \(range.min)–\(range.max)\(unit))",
                    zh: "\(v)\(unit)（允许 \(range.min)–\(range.max)\(unit)）"))
        }
        let hint = value < range.min
            ? LocalizedText(en: "too small — move closer", zh: "偏小，请靠近")
            : LocalizedText(en: "too large — move back", zh: "偏大，请后退")
        return CheckResult(id: id, title: title, status: .fail,
            detail: LocalizedText(
                en: "\(v)\(unit), \(hint.en) (need \(range.min)–\(range.max)\(unit))",
                zh: "\(v)\(unit)，\(hint.zh)（需 \(range.min)–\(range.max)\(unit)）"))
    }

    private static func boolCheck(
        id: String, title: LocalizedText, ok: Bool,
        okDetail: LocalizedText, failDetail: LocalizedText
    ) -> CheckResult {
        CheckResult(id: id, title: title, status: ok ? .pass : .fail,
                    detail: ok ? okDetail : failDetail)
    }
}
