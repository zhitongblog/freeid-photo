import Foundation
import FreeIDCore

/// The 8 languages the app (and doaipm.com) ship in. Resolved from device preferences.
enum BrandLang {
    case zh, zhTW, en, ja, ko, fr, de, it
    static var current: BrandLang {
        for id in Locale.preferredLanguages {
            let l = id.lowercased()
            if l.hasPrefix("zh") {
                return (l.contains("hant") || l.contains("-tw") || l.contains("-hk") || l.contains("-mo")) ? .zhTW : .zh
            }
            if l.hasPrefix("ja") { return .ja }
            if l.hasPrefix("ko") { return .ko }
            if l.hasPrefix("fr") { return .fr }
            if l.hasPrefix("de") { return .de }
            if l.hasPrefix("it") { return .it }
            if l.hasPrefix("en") { return .en }
        }
        return .en
    }
}

/// One string in all 8 languages; `.t` returns the device-language variant.
struct Loc8 {
    let zh, zhTW, en, ja, ko, fr, de, it: String
    var t: String {
        switch BrandLang.current {
        case .zh: return zh; case .zhTW: return zhTW; case .en: return en; case .ja: return ja
        case .ko: return ko; case .fr: return fr; case .de: return de; case .it: return it
        }
    }
}

/// All app UI strings, in 8 languages. Views reference `S.xxx.t`.
enum S {
    // Coaching (camera screen)
    static let coachReady = Loc8(zh: "很好，随时可以拍", zhTW: "很好，隨時可以拍", en: "Looks great — tap to shoot",
        ja: "いいですね、いつでも撮影できます", ko: "좋아요 — 눌러서 촬영하세요",
        fr: "Parfait — appuyez pour photographier", de: "Sieht gut aus — zum Auslösen tippen",
        it: "Perfetto — tocca per scattare")
    static let coachFindFace = Loc8(zh: "把脸放进框里", zhTW: "把臉放進框裡", en: "Put your face in the outline",
        ja: "顔を枠の中に入れてください", ko: "얼굴을 윤곽선 안에 맞춰 주세요",
        fr: "Placez votre visage dans le cadre", de: "Gesicht in die Kontur bringen",
        it: "Metti il viso nella sagoma")
    static let coachOnePerson = Loc8(zh: "画面里只留一个人", zhTW: "畫面裡只留一個人", en: "Keep just one person in frame",
        ja: "フレーム内は一人だけにしてください", ko: "화면에 한 사람만 두세요",
        fr: "Une seule personne dans le cadre", de: "Nur eine Person im Bild",
        it: "Una sola persona nell'inquadratura")
    static let coachStraighten = Loc8(zh: "坐正一点，看向镜头", zhTW: "坐正一點，看向鏡頭", en: "Sit straight, look at the camera",
        ja: "まっすぐ座ってカメラを見てください", ko: "똑바로 앉아 카메라를 보세요",
        fr: "Tenez-vous droit, regardez l'objectif", de: "Gerade sitzen, in die Kamera schauen",
        it: "Stai dritto, guarda l'obiettivo")
    static let coachCloser = Loc8(zh: "靠近一点", zhTW: "靠近一點", en: "Move a little closer",
        ja: "少し近づいてください", ko: "조금 더 가까이", fr: "Rapprochez-vous un peu",
        de: "Etwas näher kommen", it: "Avvicinati un po'")
    static let coachBack = Loc8(zh: "往后退一点", zhTW: "往後退一點", en: "Move back a little",
        ja: "少し下がってください", ko: "조금 뒤로", fr: "Reculez un peu",
        de: "Etwas zurücktreten", it: "Allontanati un po'")

    static let backCameraHint = Loc8(zh: "后置相机 · 让他人帮你拍", zhTW: "後置相機 · 讓他人幫你拍",
        en: "Back camera — have someone shoot you", ja: "背面カメラ · 誰かに撮ってもらう",
        ko: "후면 카메라 · 다른 사람이 찍어 주세요", fr: "Caméra arrière — faites-vous photographier",
        de: "Rückkamera — lass dich fotografieren", it: "Fotocamera posteriore — fatti scattare la foto")
    static let switchCamera = Loc8(zh: "切换摄像头", zhTW: "切換鏡頭", en: "Switch camera",
        ja: "カメラを切り替え", ko: "카메라 전환", fr: "Changer de caméra",
        de: "Kamera wechseln", it: "Cambia fotocamera")
    static let captureFailedTitle = Loc8(zh: "拍摄失败", zhTW: "拍攝失敗", en: "Capture failed",
        ja: "撮影に失敗しました", ko: "촬영 실패", fr: "Échec de la capture",
        de: "Aufnahme fehlgeschlagen", it: "Acquisizione non riuscita")
    static let captureError = Loc8(zh: "没拍清楚，让脸保持在框里再试一次", zhTW: "沒拍清楚，讓臉保持在框裡再試一次",
        en: "Didn't catch that — keep your face in the frame and tap again.",
        ja: "うまく撮れませんでした。顔を枠内に保ってもう一度。",
        ko: "잘 찍히지 않았어요. 얼굴을 화면 안에 두고 다시 눌러 주세요.",
        fr: "Photo manquée — gardez le visage dans le cadre et réessayez.",
        de: "Nicht erfasst — Gesicht im Rahmen halten und erneut tippen.",
        it: "Scatto non riuscito — tieni il viso nel riquadro e riprova.")
    static let ok = Loc8(zh: "好", zhTW: "好", en: "OK", ja: "OK", ko: "확인", fr: "OK", de: "OK", it: "OK")

    // Result screen
    static let readyToUse = Loc8(zh: "已按规格生成，可直接使用", zhTW: "已按規格生成，可直接使用",
        en: "Ready to use — sized to spec", ja: "規格どおりに生成、そのまま使えます",
        ko: "규격에 맞게 생성됨 — 바로 사용 가능", fr: "Prêt à l'emploi — aux dimensions requises",
        de: "Fertig — auf Spec-Maß gebracht", it: "Pronta — alle dimensioni richieste")
    static let backgroundLabel = Loc8(zh: "背景颜色", zhTW: "背景顏色", en: "Background",
        ja: "背景色", ko: "배경색", fr: "Arrière-plan", de: "Hintergrund", it: "Sfondo")
    /// %@ = localized color name.
    static let requiredBgNote = Loc8(zh: "已按该证件要求使用 %@ 背景", zhTW: "已按該證件要求使用 %@ 背景",
        en: "Set to the required %@ background", ja: "この証明書に必要な %@ の背景に設定しました",
        ko: "이 문서에 필요한 %@ 배경으로 설정됨", fr: "Arrière-plan %@ requis appliqué",
        de: "Auf den erforderlichen %@ Hintergrund gesetzt", it: "Impostato sullo sfondo %@ richiesto")
    /// %@ = localized color name.
    static let strictBgWarning = Loc8(zh: "该国要求原图，未替换背景，请用 %@ 纯色背景拍摄",
        zhTW: "該國要求原圖，未替換背景，請用 %@ 純色背景拍攝",
        en: "This country requires an unedited photo — shoot against a real %@ backdrop.",
        ja: "この国は無加工写真が必要です。実際の %@ の背景で撮影してください。",
        ko: "이 국가는 미편집 사진이 필요합니다 — 실제 %@ 배경에서 촬영하세요.",
        fr: "Ce pays exige une photo non retouchée — photographiez sur un fond %@ réel.",
        de: "Dieses Land verlangt ein unbearbeitetes Foto — vor echtem %@ Hintergrund aufnehmen.",
        it: "Questo paese richiede una foto non modificata — scatta su uno sfondo %@ reale.")
    static let retake = Loc8(zh: "重拍", zhTW: "重拍", en: "Retake", ja: "撮り直し", ko: "다시 찍기",
        fr: "Reprendre", de: "Erneut", it: "Riscatta")
    static let share = Loc8(zh: "分享", zhTW: "分享", en: "Share", ja: "共有", ko: "공유",
        fr: "Partager", de: "Teilen", it: "Condividi")
    static let saveToPhotos = Loc8(zh: "保存到相册", zhTW: "儲存到相簿", en: "Save to Photos",
        ja: "写真に保存", ko: "사진에 저장", fr: "Enregistrer dans Photos",
        de: "In Fotos sichern", it: "Salva in Foto")
    static let saving = Loc8(zh: "保存中…", zhTW: "儲存中…", en: "Saving…", ja: "保存中…", ko: "저장 중…",
        fr: "Enregistrement…", de: "Sichern…", it: "Salvataggio…")
    static let saved = Loc8(zh: "已保存", zhTW: "已儲存", en: "Saved", ja: "保存しました", ko: "저장됨",
        fr: "Enregistré", de: "Gesichert", it: "Salvata")
    static let tryAgain = Loc8(zh: "再试一次", zhTW: "再試一次", en: "Try again", ja: "もう一度", ko: "다시 시도",
        fr: "Réessayer", de: "Erneut versuchen", it: "Riprova")
    static let yourPhoto = Loc8(zh: "你的证件照", zhTW: "你的證件照", en: "Your photo", ja: "あなたの写真",
        ko: "내 사진", fr: "Votre photo", de: "Dein Foto", it: "La tua foto")
    static let done = Loc8(zh: "完成", zhTW: "完成", en: "Done", ja: "完了", ko: "완료",
        fr: "Terminé", de: "Fertig", it: "Fine")

    // Spec picker
    static let chooseDoc = Loc8(zh: "选择证件", zhTW: "選擇證件", en: "Choose document",
        ja: "証明書を選択", ko: "문서 선택", fr: "Choisir le document",
        de: "Dokument wählen", it: "Scegli documento")
    static let cancel = Loc8(zh: "取消", zhTW: "取消", en: "Cancel", ja: "キャンセル", ko: "취소",
        fr: "Annuler", de: "Abbrechen", it: "Annulla")
}

/// Localized country / document-type / color names, composed for spec rows.
enum SpecText {
    static func country(_ code: String) -> Loc8 {
        switch code.uppercased() {
        case "CN": return Loc8(zh: "中国", zhTW: "中國", en: "China", ja: "中国", ko: "중국", fr: "Chine", de: "China", it: "Cina")
        case "US": return Loc8(zh: "美国", zhTW: "美國", en: "United States", ja: "アメリカ", ko: "미국", fr: "États-Unis", de: "USA", it: "Stati Uniti")
        case "CA": return Loc8(zh: "加拿大", zhTW: "加拿大", en: "Canada", ja: "カナダ", ko: "캐나다", fr: "Canada", de: "Kanada", it: "Canada")
        case "AU": return Loc8(zh: "澳大利亚", zhTW: "澳洲", en: "Australia", ja: "オーストラリア", ko: "호주", fr: "Australie", de: "Australien", it: "Australia")
        case "GB", "UK": return Loc8(zh: "英国", zhTW: "英國", en: "United Kingdom", ja: "イギリス", ko: "영국", fr: "Royaume-Uni", de: "Vereinigtes Königreich", it: "Regno Unito")
        case "KR": return Loc8(zh: "韩国", zhTW: "韓國", en: "South Korea", ja: "韓国", ko: "대한민국", fr: "Corée du Sud", de: "Südkorea", it: "Corea del Sud")
        case "IN": return Loc8(zh: "印度", zhTW: "印度", en: "India", ja: "インド", ko: "인도", fr: "Inde", de: "Indien", it: "India")
        case "JP": return Loc8(zh: "日本", zhTW: "日本", en: "Japan", ja: "日本", ko: "일본", fr: "Japon", de: "Japan", it: "Giappone")
        case "SG": return Loc8(zh: "新加坡", zhTW: "新加坡", en: "Singapore", ja: "シンガポール", ko: "싱가포르", fr: "Singapour", de: "Singapur", it: "Singapore")
        case "EU": return Loc8(zh: "申根", zhTW: "申根", en: "Schengen", ja: "シェンゲン", ko: "솅겐", fr: "Schengen", de: "Schengen", it: "Schengen")
        default: return Loc8(zh: code, zhTW: code, en: code, ja: code, ko: code, fr: code, de: code, it: code)
        }
    }

    static func docType(_ type: DocType) -> Loc8 {
        switch type {
        case .passport: return Loc8(zh: "护照", zhTW: "護照", en: "Passport", ja: "パスポート", ko: "여권", fr: "Passeport", de: "Reisepass", it: "Passaporto")
        case .visa: return Loc8(zh: "签证", zhTW: "簽證", en: "Visa", ja: "ビザ", ko: "비자", fr: "Visa", de: "Visum", it: "Visto")
        case .idCard: return Loc8(zh: "身份证", zhTW: "身分證", en: "ID Card", ja: "IDカード", ko: "신분증", fr: "Carte d'identité", de: "Ausweis", it: "Carta d'identità")
        case .driverLicense: return Loc8(zh: "驾照", zhTW: "駕照", en: "Driver License", ja: "運転免許", ko: "운전면허", fr: "Permis", de: "Führerschein", it: "Patente")
        case .residencePermit: return Loc8(zh: "居留许可", zhTW: "居留許可", en: "Residence Permit", ja: "在留カード", ko: "거주허가", fr: "Titre de séjour", de: "Aufenthaltstitel", it: "Permesso di soggiorno")
        case .general: return Loc8(zh: "证件照", zhTW: "證件照", en: "ID Photo", ja: "証明写真", ko: "증명사진", fr: "Photo d'identité", de: "Passfoto", it: "Foto tessera")
        }
    }

    /// "中国 证件照 25×35" / "China ID Photo 25×35" — country + type, plus size for general photos.
    static func name(_ spec: PhotoSpec) -> String {
        var s = country(spec.country).t + " " + docType(spec.docType).t
        if spec.docType == .general {
            s += " \(Int(spec.outputSize.widthMM))×\(Int(spec.outputSize.heightMM))"
        }
        return s
    }

    /// Localized required-background color name, from the spec's hex.
    static func colorName(_ hex: String) -> String {
        let h = hex.uppercased()
        if h == "#FFFFFF" {
            return Loc8(zh: "白色", zhTW: "白色", en: "white", ja: "白", ko: "흰색", fr: "blanc", de: "weißen", it: "bianco").t
        }
        // EDEDED / ECECEC and other light grays
        return Loc8(zh: "浅灰白", zhTW: "淺灰白", en: "off-white", ja: "オフホワイト", ko: "연회색",
                    fr: "gris clair", de: "hellgrauen", it: "grigio chiaro").t
    }
}
