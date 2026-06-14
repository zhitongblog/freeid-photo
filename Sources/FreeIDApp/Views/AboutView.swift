import SwiftUI

/// doaipm. brand assets, matched to the live site doaipm.com (lowercase wordmark with the
/// "ai" + "." in a blue→purple gradient, dark starfield theme).
enum Brand {
    static let url = URL(string: "https://doaipm.com")!
    static let xURL = URL(string: "https://x.com/zhitong45")!
    static let gradient = LinearGradient(
        colors: [Color(red: 0.36, green: 0.56, blue: 0.98), Color(red: 0.62, green: 0.40, blue: 0.96)],
        startPoint: .leading, endPoint: .trailing)
}

/// Tappable "doaipm." wordmark — the brand entry point used in nav bars and footers.
struct BrandWordmark: View {
    var size: CGFloat = 18
    var base: Color = .primary
    var body: some View {
        HStack(spacing: 0) {
            Text("do").foregroundStyle(base)
            Text("ai").foregroundStyle(Brand.gradient)
            Text("pm").foregroundStyle(base)
            Text(".").foregroundStyle(Brand.gradient)
        }
        .font(.system(size: size, weight: .heavy, design: .rounded))
    }
}

/// Personal-brand / about screen. FreeID Photo is a doaipm. product; this puts the brand
/// front and centre, mirrors the doaipm.com look, and drives traffic to the site.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.12),
                                        Color(red: 0.08, green: 0.06, blue: 0.19)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer()
                    BrandWordmark(size: 56, base: .white)
                    Text(zhEn("成为 AI 时代的产品经理", "Become an AI-era product manager"))
                        .font(.headline).foregroundStyle(.white.opacity(0.92))
                    Text(zhEn("言出法随 · 一句话，AI 就做出来", "Say it — and AI builds it"))
                        .font(.subheadline).foregroundStyle(Brand.gradient)
                    Text(zhEn("doaipm = DO · AI · PM。不懂技术反而是优势——你把想法说清楚，剩下交给 AI。FreeID Photo 就是这样做出来的作品之一。",
                              "doaipm = DO · AI · PM. FreeID Photo is one of the products built exactly this way."))
                        .font(.footnote).foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32).padding(.top, 6)
                    Spacer()

                    Link(destination: Brand.url) {
                        Label(zhEn("访问 doaipm.com", "Visit doaipm.com"), systemImage: "safari.fill")
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    Link(destination: Brand.xURL) {
                        Text(zhEn("在 X 关注 @zhitong45", "Follow @zhitong45 on X"))
                            .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle(zhEn("关于", "About"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(zhEn("完成", "Done")) { dismiss() }.tint(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
