import SwiftUI
import FreeIDCore

/// Compact live status. Instead of listing every check, it shows one clear headline
/// (ready vs. what's blocking) and only the items that still need attention — so a
/// good shot reads as a single green line, not a wall of checkmarks.
struct ComplianceHUD: View {
    let report: ComplianceReport?
    let languageCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headline
            ForEach(issues.prefix(3), id: \.id) { check in
                HStack(spacing: 8) {
                    Image(systemName: check.status == .fail ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(check.status == .fail ? .red : .yellow)
                    Text(check.detail.text(forLanguage: languageCode))
                        .font(.subheadline)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    private var issues: [CheckResult] {
        guard let report else { return [] }
        // Show blocking fails first, then advisory warnings.
        return report.failures + report.warnings
    }

    @ViewBuilder private var headline: some View {
        if report == nil {
            label("Point the camera at your face", "viewfinder", .white)
        } else if report!.isCompliant {
            label(zhEn("可以拍了，点绿色快门", "Ready — tap the green button"), "checkmark.circle.fill", .green)
        } else {
            label(zhEn("再调整一下", "Almost there — adjust below"), "camera.metering.center.weighted", .white)
        }
    }

    private func label(_ text: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.headline)
        }
    }

    private func zhEn(_ zh: String, _ en: String) -> String {
        languageCode.lowercased().hasPrefix("zh") ? zh : en
    }
}
