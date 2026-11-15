import SwiftUI
import AppKit

// Source photos live next to this script in ./assets (an AI-generated synthetic face + its
// white/blue/red background variants made via `freeidctl bgreplace`). No real person is used.
// Outputs 6.9" (1290×2796) marketing screenshots for all 8 App Store locales into ./screenshots.
let BASE_DIR = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let ASSETS = BASE_DIR.appendingPathComponent("assets").path
let OUT_DIR = BASE_DIR.appendingPathComponent("screenshots").path

let brand = LinearGradient(
    colors: [Color(red: 0.36, green: 0.56, blue: 0.98), Color(red: 0.62, green: 0.40, blue: 0.96)],
    startPoint: .leading, endPoint: .trailing)
let bg = LinearGradient(
    colors: [Color(red: 0.93, green: 0.95, blue: 1.0), Color(red: 0.90, green: 0.92, blue: 0.99)],
    startPoint: .top, endPoint: .bottom)

func wm(_ s: CGFloat) -> some View {
    HStack(spacing: 0) {
        Text("do").foregroundStyle(Color(white: 0.2))
        Text("ai").foregroundStyle(brand)
        Text("pm").foregroundStyle(Color(white: 0.2))
        Text(".").foregroundStyle(brand)
    }
    .font(.system(size: s, weight: .heavy, design: .rounded))
}

private enum Bust {
    static func nh(_ h: CGRect) -> CGFloat { h.width * 0.24 }
    static func ny(_ h: CGRect) -> CGFloat { h.maxY - h.height * 0.02 }
    static func ins(_ f: CGRect) -> CGFloat { f.width * 0.05 }
}

struct Shoulders: Shape {
    let hr: CGRect
    let f: CGRect
    func path(in r: CGRect) -> Path {
        var p = Path()
        let nh = Bust.nh(hr), ny = Bust.ny(hr), b = f.maxY, d = b - ny
        let lx = f.minX + Bust.ins(f), rx = f.maxX - Bust.ins(f)
        p.move(to: CGPoint(x: hr.midX - nh, y: ny))
        p.addCurve(to: CGPoint(x: lx, y: b),
                   control1: CGPoint(x: hr.midX - nh, y: ny + d * 0.42),
                   control2: CGPoint(x: lx, y: b - d * 0.55))
        p.move(to: CGPoint(x: hr.midX + nh, y: ny))
        p.addCurve(to: CGPoint(x: rx, y: b),
                   control1: CGPoint(x: hr.midX + nh, y: ny + d * 0.42),
                   control2: CGPoint(x: rx, y: b - d * 0.55))
        return p
    }
}

struct GuideContent: View {
    var body: some View {
        GeometryReader { geo in
            let aspect = 0.688, headFrac = 0.635, eyeFB = 0.656
            let fw = min(geo.size.width * 0.82, geo.size.height * 0.62 * aspect)
            let fh = fw / aspect
            let fr = CGRect(x: (geo.size.width - fw) / 2, y: geo.size.height * 0.46 - fh / 2, width: fw, height: fh)
            let hh = fh * headFrac, hw = hh * 0.74, eyeY = fr.maxY - fh * eyeFB, hcy = eyeY - hh * 0.46 + hh / 2
            let hr = CGRect(x: fr.midX - hw / 2, y: hcy - hh / 2, width: hw, height: hh)
            let dash = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [14, 11])
            ZStack {
                Image(nsImage: NSImage(contentsOfFile: ASSETS + "/face2.jpg")!)
                    .resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: geo.size))
                    p.addRoundedRect(in: fr, cornerSize: CGSize(width: 20, height: 20))
                }
                .fill(.black.opacity(0.45), style: FillStyle(eoFill: true))
                Ellipse().stroke(.white.opacity(0.95), style: dash).frame(width: hw, height: hh).position(x: hr.midX, y: hr.midY)
                Shoulders(hr: hr, f: fr).stroke(.white.opacity(0.95), style: dash)
                RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: fw, height: fh).position(x: fr.midX, y: fr.midY)
            }
        }
    }
}

struct ColorsContent: View {
    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 14) {
                ForEach([ASSETS + "/out_cn.jpg", ASSETS + "/bg_blue.jpg", ASSETS + "/bg_red.jpg"], id: \.self) { f in
                    Image(nsImage: NSImage(contentsOfFile: f)!)
                        .resizable().scaledToFit().frame(width: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10)).shadow(radius: 6)
                }
            }
            HStack(spacing: 26) {
                ForEach([Color.white, Color(red: 0.26, green: 0.56, blue: 0.86), Color(red: 0.85, green: 0, blue: 0.1)], id: \.self) { c in
                    Circle().fill(c).frame(width: 34, height: 34).overlay(Circle().stroke(.gray.opacity(0.4)))
                }
            }
        }
    }
}

struct SpecsContent: View {
    let rows: [(String, String)]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, r in
                HStack {
                    Text(r.0).font(.system(size: 30))
                    Text(r.1).font(.system(size: 25, weight: .medium)).foregroundStyle(Color(white: 0.15)).lineLimit(1)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                .padding(.vertical, 15).padding(.horizontal, 22)
                if idx < rows.count - 1 { Divider() }
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(radius: 8)
        .padding(.horizontal, 30)
    }
}

struct Shot<Content: View>: View {
    let head: String
    let sub: String
    let content: Content
    init(_ h: String, _ s: String, @ViewBuilder _ c: () -> Content) { head = h; sub = s; content = c() }
    var body: some View {
        ZStack {
            bg
            VStack(spacing: 0) {
                Spacer().frame(height: 82)
                Text(head)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(white: 0.12))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
                    .fixedSize(horizontal: false, vertical: true)
                Text(sub)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(brand)
                    .padding(.top, 12)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
                Spacer().frame(height: 36)
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer().frame(height: 28)
                wm(30).opacity(0.6).padding(.bottom, 38)
            }
        }
        .frame(width: 645, height: 1398)
    }
}

struct LocaleCopy {
    let slug: String
    let s1Head: String; let s1Sub: String
    let s2Head: String; let s2Sub: String
    let s3Head: String; let s3Sub: String
    let rows: [(String, String)]
}

let copies: [LocaleCopy] = [
    LocaleCopy(
        slug: "zh",
        s1Head: "精准取景\n合规证件照", s1Sub: "智能检测眼镜反光 · 光线与姿态",
        s2Head: "一键换底色与微调", s2Sub: "白 / 蓝 / 红 · 历史原片随时重导出",
        s3Head: "12 地区 · 24 种规格", s3Sub: "全程设备本地处理 · 绝不上传",
        rows: [("🇨🇳", "一寸 / 二寸 / 驾驶证 / 社保卡"), ("🎓", "四六级 / 教资 / 学信网采集"),
               ("🇭🇰", "港澳台通行证 / 香港特区护照"), ("🇺🇸", "美国护照 / 签证 2×2"),
               ("🇪🇺", "申根签证 / 英国护照"), ("🇯🇵", "日本签证 / 履历书 30×40"),
               ("🇰🇷", "韩国护照 · 台湾入台证"), ("🖨️", "自定义尺寸 · KB 限制 · 排版打印")]
    ),
    LocaleCopy(
        slug: "zhtw",
        s1Head: "精準取景\n合規證件照", s1Sub: "智慧偵測鏡片反光 · 光線與姿勢",
        s2Head: "一鍵換底色與微調", s2Sub: "白 / 藍 / 紅 · 本機原片隨時重匯出",
        s3Head: "12 地區 · 24 種規格", s3Sub: "全程本機離線處理 · 絕不上傳",
        rows: [("🇹🇼", "台灣護照 / 入台證 35×45"), ("🇭🇰", "香港特區護照 / 回鄉證"),
               ("🇺🇸", "美國護照 / 簽證 2×2"), ("🇯🇵", "日本簽證 / 履歷書 30×40"),
               ("🇪🇺", "申根簽證 / 英國護照"), ("🇰🇷", "韓國 / 加拿大 / 澳洲護照"),
               ("🇨🇳", "1吋 / 2吋 / 港澳台通行證"), ("🖨️", "自訂公釐 · KB 上限 · 列印排版")]
    ),
    LocaleCopy(
        slug: "en",
        s1Head: "Framed right,\nevery time", s1Sub: "Checks pose, lighting & lens glare",
        s2Head: "Swap backdrop\n& fine-tune", s2Sub: "White / Blue / Red · 1-tap spec switch",
        s3Head: "12 regions\n24 official specs", s3Sub: "100% on-device · nothing uploaded",
        rows: [("🇺🇸", "US Passport & Visa 2×2"), ("🇬🇧", "UK Passport · Canada · Australia"),
               ("🇪🇺", "Schengen Visa 35×45 mm"), ("🇯🇵", "Japan Visa & Resume 30×40"),
               ("🇰🇷", "South Korea & Singapore"), ("🇭🇰", "Hong Kong & Taiwan Passports"),
               ("🇨🇳", "China Passport, ID & Driver"), ("🖨️", "Custom mm · Max KB · Print Sheets")]
    ),
    LocaleCopy(
        slug: "ja",
        s1Head: "ガイドに合わせて\n規格どおりに撮影", s1Sub: "姿勢・明るさ・眼鏡の反射も自動判定",
        s2Head: "背景変更＆自然な補正", s2Sub: "白・青・赤 · 履歴から別サイズ再出力",
        s3Head: "12地域・24規格に対応", s3Sub: "すべて端末内で完結 · 送信なし",
        rows: [("🇯🇵", "履歴書・在留カード 30×40mm"), ("🇯🇵", "日本ビザ・パスポート規格"),
               ("🇺🇸", "米国パスポート・ビザ 2×2"), ("🇪🇺", "シェンゲンビザ・英国パスポート"),
               ("🇰🇷", "韓国・台湾・香港パスポート"), ("🇨🇳", "中国パスポート・運転免許"),
               ("🌏", "カナダ・豪州・シンガポール"), ("🖨️", "カスタムmm · 容量指定 · 印刷シート")]
    ),
    LocaleCopy(
        slug: "ko",
        s1Head: "가이드에 맞춰\n정확한 규격 촬영", s1Sub: "자세 · 조명 균형 · 안경 빛 반사 체크",
        s2Head: "배경 변경 & 자연 보정", s2Sub: "흰색 / 파랑 / 빨강 · 규격 즉시 전환",
        s3Head: "12개 지역 · 24종 규격", s3Sub: "100% 기기 내 처리 · 서버 업로드 없음",
        rows: [("🇰🇷", "대한민국 여권 35×45mm"), ("🇺🇸", "미국 여권 / 비자 2×2"),
               ("🇯🇵", "일본 비자 / 이력서 30×40"), ("🇪🇺", "유럽 솅겐 비자 · 영국 여권"),
               ("🇭🇰", "홍콩 · 대만 · 싱가포르 여권"), ("🇨🇳", "중국 여권 · 비자 · 운전면허"),
               ("🌏", "캐나다 · 호주 · 인도 여권"), ("🖨️", "사용자 mm · KB 제한 · 인화 시트")]
    ),
    LocaleCopy(
        slug: "fr",
        s1Head: "Cadrage conforme\ndès la prise", s1Sub: "Vérifie posture, lumière et reflets",
        s2Head: "Fond uni &\nretouche douce", s2Sub: "Blanc / Bleu / Rouge · selon le pays",
        s3Head: "12 régions\n24 formats officiels", s3Sub: "100 % sur l'iPhone · aucun envoi",
        rows: [("🇪🇺", "Visa Schengen / UE 35×45 mm"), ("🇺🇸", "Passeport & Visa USA 2×2"),
               ("🇬🇧", "Passeport Royaume-Uni"), ("🇨🇦", "Passeport Canada 50×70 mm"),
               ("🇯🇵", "Visa Japon & CV 30×40 mm"), ("🇰🇷", "Corée · Singapour · Australie"),
               ("🇭🇰", "Hong Kong · Taïwan · Chine"), ("🖨️", "Taille mm · Ko max · Planche photo")]
    ),
    LocaleCopy(
        slug: "de",
        s1Head: "Biometrisch exakt\neingerahmt", s1Sub: "Prüft Haltung, Licht & Glasreflexe",
        s2Head: "Hintergrund &\nfeine Korrektur", s2Sub: "Weiß / Blau / Rot · je nach Vorschrift",
        s3Head: "12 Regionen\n24 offizielle Maße", s3Sub: "100 % lokal auf dem Gerät",
        rows: [("🇪🇺", "Schengen / EU-Passfoto 35×45"), ("🇺🇸", "USA Reisepass & Visum 2×2"),
               ("🇬🇧", "UK Reisepass · Kanada · Australien"), ("🇯🇵", "Japan Visum & Bewerbung 30×40"),
               ("🇰🇷", "Südkorea · Singapur · Indien"), ("🇭🇰", "Hongkong · Taiwan · China"),
               ("🪪", "Führerschein & Ausweisformate"), ("🖨️", "Eigene mm · Max. KB · Druckbogen")]
    ),
    LocaleCopy(
        slug: "it",
        s1Head: "Inquadratura\na norma subito", s1Sub: "Controlla postura, luce e riflessi",
        s2Head: "Cambia sfondo\ne regola la luce", s2Sub: "Bianco / Blu / Rosso · per paese",
        s3Head: "12 regioni\n24 formati ufficiali", s3Sub: "100% sul dispositivo · zero upload",
        rows: [("🇪🇺", "Schengen / UE 35×45 mm"), ("🇺🇸", "Passaporto & Visto USA 2×2"),
               ("🇬🇧", "Regno Unito · Canada · Australia"), ("🇯🇵", "Giappone Visto & CV 30×40"),
               ("🇰🇷", "Corea del Sud · Singapore"), ("🇭🇰", "Hong Kong · Taiwan · Cina"),
               ("🪪", "Patente & Carta d'identità"), ("🖨️", "Formato mm · KB max · Foglio stampa")]
    ),
]

@MainActor
func snap<X: View>(_ v: X, _ p: String) {
    let r = ImageRenderer(content: v)
    r.scale = 2
    if let i = r.nsImage,
       let t = i.tiffRepresentation,
       let b = NSBitmapImageRep(data: t),
       let png = b.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: p))
        print("wrote", p)
    }
}

try? FileManager.default.createDirectory(atPath: OUT_DIR, withIntermediateDirectories: true)

MainActor.assumeIsolated {
    for c in copies {
        snap(Shot(c.s1Head, c.s1Sub) { GuideContent() }, "\(OUT_DIR)/ss_\(c.slug)_1.png")
        snap(Shot(c.s2Head, c.s2Sub) { ColorsContent() }, "\(OUT_DIR)/ss_\(c.slug)_2.png")
        snap(Shot(c.s3Head, c.s3Sub) { SpecsContent(rows: c.rows) }, "\(OUT_DIR)/ss_\(c.slug)_3.png")
    }
}
