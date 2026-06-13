import SwiftUI
import FreeIDCore

/// The live checklist overlay. Each requirement shows green (pass), amber (warn), or
/// red (fail) in real time as the user adjusts. This is the product's core moment:
/// the user sees exactly what to fix and shoots only when everything is green.
struct ComplianceHUD: View {
    let report: ComplianceReport?
    let languageCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let report {
                ForEach(report.checks, id: \.id) { check in
                    HStack(spacing: 8) {
                        Image(systemName: icon(check.status))
                            .foregroundStyle(color(check.status))
                        Text(check.title.text(forLanguage: languageCode))
                            .font(.subheadline).bold()
                        Spacer()
                        if check.status != .pass {
                            Text(check.detail.text(forLanguage: languageCode))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1).truncationMode(.tail)
                        }
                    }
                }
            } else {
                Label("Point the camera at your face", systemImage: "viewfinder")
                    .font(.subheadline)
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }

    private func icon(_ s: CheckStatus) -> String {
        switch s {
        case .pass: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.circle.fill"
        }
    }
    private func color(_ s: CheckStatus) -> Color {
        switch s {
        case .pass: return .green
        case .warn: return .yellow
        case .fail: return .red
        }
    }
}
