import SwiftUI

/// doaipm. brand assets + copy, mirrored 1:1 from the live multilingual site doaipm.com.
/// (Shared `BrandLang` / `Loc8` live in Localization.swift.)
enum Brand {
    static let url = URL(string: "https://doaipm.com")!
    static let xURL = URL(string: "https://x.com/zhitong45")!
    static let gradient = LinearGradient(
        colors: [Color(red: 0.36, green: 0.56, blue: 0.98), Color(red: 0.62, green: 0.40, blue: 0.96)],
        startPoint: .leading, endPoint: .trailing)

    static let slogan = Loc8(
        zh: "言出法随", zhTW: "言出法隨",
        en: "Speak it. AI builds it.",
        ja: "言葉にすれば、AIが作る", ko: "말하면 AI가 만든다",
        fr: "Dites-le, l'IA le construit", de: "Sag es, die KI baut es",
        it: "Dillo, l'IA lo costruisce")
    static let subSlogan = Loc8(
        zh: "一句话，AI 就做出来", zhTW: "一句話，AI 就做出來",
        en: "Say the word — Claude makes it real.",
        ja: "一言で、AIがそれを実現する", ko: "한 마디면 AI가 바로 만들어 줍니다",
        fr: "une phrase suffit", de: "Ein Satz — und es ist fertig",
        it: "Una frase e il risultato è già pronto")
    static let tagline = Loc8(
        zh: "成为 AI 时代的产品经理", zhTW: "成為 AI 時代的產品經理",
        en: "Becoming a PM in the AI era",
        ja: "AI 時代のプロダクトマネージャーになる", ko: "AI 시대의 제품 매니저 되기",
        fr: "Devenir PM à l'ère de l'IA", de: "Produktmanager:in im KI-Zeitalter werden",
        it: "Diventare PM nell'era dell'IA")
    static let about = Loc8(
        zh: "FreeID Photo 是 doaipm. 用 AI 做出来的作品之一。",
        zhTW: "FreeID Photo 是 doaipm. 用 AI 做出來的作品之一。",
        en: "FreeID Photo is one of doaipm.'s products, built with AI.",
        ja: "FreeID Photo は doaipm. が AI で作った作品のひとつです。",
        ko: "FreeID Photo는 doaipm.이 AI로 만든 작품 중 하나입니다.",
        fr: "FreeID Photo est l'un des produits de doaipm., conçu avec l'IA.",
        de: "FreeID Photo ist eines von doaipm.s mit KI gebauten Produkten.",
        it: "FreeID Photo è uno dei prodotti di doaipm., creato con l'IA.")
    static let visit = Loc8(
        zh: "访问 doaipm.com", zhTW: "造訪 doaipm.com", en: "Visit doaipm.com",
        ja: "doaipm.com を見る", ko: "doaipm.com 방문", fr: "Visiter doaipm.com",
        de: "doaipm.com besuchen", it: "Visita doaipm.com")
    static let followX = Loc8(
        zh: "在 X 关注 @zhitong45", zhTW: "在 X 追蹤 @zhitong45", en: "Follow @zhitong45 on X",
        ja: "X で @zhitong45 をフォロー", ko: "X에서 @zhitong45 팔로우",
        fr: "Suivre @zhitong45 sur X", de: "@zhitong45 auf X folgen", it: "Segui @zhitong45 su X")
    static let aboutTitle = Loc8(
        zh: "关于", zhTW: "關於", en: "About", ja: "概要", ko: "소개",
        fr: "À propos", de: "Über", it: "Info")
    static let done = Loc8(
        zh: "完成", zhTW: "完成", en: "Done", ja: "完了", ko: "완료",
        fr: "Terminé", de: "Fertig", it: "Fine")
    // Result-screen footer: [prefix] doaipm. [suffix]
    static let creditPrefix = Loc8(
        zh: "由 ", zhTW: "由 ", en: "by ", ja: "", ko: "", fr: "par ", de: "von ", it: "di ")
    static let creditSuffix = Loc8(
        zh: " 出品 · doaipm.com", zhTW: " 出品 · doaipm.com", en: " · doaipm.com",
        ja: " 制作 · doaipm.com", ko: " 제작 · doaipm.com",
        fr: " · doaipm.com", de: " · doaipm.com", it: " · doaipm.com")
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

/// Personal-brand / about screen. Mirrors the doaipm.com look and copy, in the device's
/// language (the same 8 languages the site supports), and drives traffic to the site.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.12),
                                        Color(red: 0.08, green: 0.06, blue: 0.19)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 16) {
                            Spacer(minLength: 16)
                            BrandWordmark(size: 56, base: .white)
                            Text(Brand.slogan.t)
                                .font(.title2.weight(.bold)).foregroundStyle(Brand.gradient)
                                .multilineTextAlignment(.center).padding(.horizontal, 24)
                            Text(Brand.subSlogan.t)
                                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center).padding(.horizontal, 28)
                            Text(Brand.tagline.t)
                                .font(.footnote).foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                            Text(Brand.about.t)
                                .font(.footnote).foregroundStyle(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32).padding(.top, 8)
                            Spacer(minLength: 16)

                            Link(destination: Brand.url) {
                                Label(Brand.visit.t, systemImage: "safari.fill")
                                    .font(.headline).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal)

                            Link(destination: Brand.xURL) {
                                Text(Brand.followX.t)
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(.bottom, 18)
                        }
                        .frame(minHeight: geo.size.height)
                    }
                }
            }
            .navigationTitle(Brand.aboutTitle.t)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Brand.done.t) { dismiss() }.tint(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
