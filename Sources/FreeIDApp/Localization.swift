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

    static let includeShoulders = Loc8(
        zh: "头和肩膀一起放进框", zhTW: "頭和肩膀一起放進框",
        en: "Fit your head AND shoulders in", ja: "頭と肩を枠に収めて",
        ko: "머리와 어깨를 함께 맞추세요", fr: "Cadrez la tête et les épaules",
        de: "Kopf und Schultern einpassen", it: "Inquadra testa e spalle")
    static let backCameraHint = Loc8(zh: "后置相机 · 语音引导与对准自动拍照已开启", zhTW: "後置相機 · 語音引導與對準自動拍照已開啟",
        en: "Back camera — voice coach & auto-shutter active", ja: "背面カメラ · 音声ガイドと自動シャッター有効",
        ko: "후면 카메라 · 음성 안내 및 자동 촬영 켜짐", fr: "Caméra arrière — guidage vocal et déclenchement auto",
        de: "Rückkamera — Sprachführung & Auto-Auslöser aktiv", it: "Fotocamera posteriore — guida vocale e scatto auto")
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

    // Result screen & adjustments
    static let readyToUse = Loc8(zh: "已按规格生成，可直接使用", zhTW: "已按規格生成，可直接使用",
        en: "Ready to use — sized to spec", ja: "規格どおりに生成、そのまま使えます",
        ko: "규격에 맞게 생성됨 — 바로 사용 가능", fr: "Prêt à l'emploi — aux dimensions requises",
        de: "Fertig — auf Spec-Maß gebracht", it: "Pronta — alle dimensioni richieste")
    static let backgroundLabel = Loc8(zh: "背景颜色", zhTW: "背景顏色", en: "Background",
        ja: "背景色", ko: "배경색", fr: "Arrière-plan", de: "Hintergrund", it: "Sfondo")
    static let brightnessLabel = Loc8(zh: "亮度微调", zhTW: "亮度微調", en: "Brightness",
        ja: "明るさ調整", ko: "밝기 조절", fr: "Luminosité", de: "Helligkeit", it: "Luminosità")
    static let smoothingLabel = Loc8(zh: "自然肤质", zhTW: "自然膚質", en: "Natural skin",
        ja: "自然な肌補正", ko: "자연스러운 피부", fr: "Grain de peau naturel", de: "Natürliche Haut", it: "Pelle naturale")
    static let resetAdjustments = Loc8(zh: "重置微调", zhTW: "重置微調", en: "Reset",
        ja: "リセット", ko: "초기화", fr: "Réinitialiser", de: "Zurücksetzen", it: "Reimposta")
    static let switchSpec = Loc8(zh: "换规格重导出", zhTW: "換規格重匯出", en: "Change spec",
        ja: "別のサイズで出力", ko: "다른 규격으로 변경", fr: "Changer de format", de: "Format wechseln", it: "Cambia formato")
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

    // History originals
    static let historyTitle = Loc8(zh: "历史原片", zhTW: "歷史原片", en: "Recent photos",
        ja: "撮影履歴", ko: "최근 원본", fr: "Photos récentes", de: "Letzte Aufnahmen", it: "Foto recenti")
    static let historyNote = Loc8(
        zh: "原片仅保存在本机，点选即可按当前规格一键导出证件照。",
        zhTW: "原片僅保存在本機，點選即可按目前規格一鍵匯出證件照。",
        en: "Originals stay on this device — tap one to export it in the selected spec.",
        ja: "元画像は端末内のみに保存されます。タップすると選択中の規格で書き出します。",
        ko: "원본은 기기에만 저장됩니다 — 탭하면 현재 규격으로 바로 생성됩니다.",
        fr: "Les originaux restent sur l'appareil — touchez-en un pour l'exporter au format choisi.",
        de: "Originale bleiben auf dem Gerät — antippen, um im gewählten Format zu exportieren.",
        it: "Gli originali restano sul dispositivo — toccane uno per esportarlo nel formato scelto.")
    static let historyEmpty = Loc8(zh: "还没有历史原片，拍一张或从相册导入后会自动留存",
        zhTW: "還沒有歷史原片，拍一張或從相簿匯入後會自動留存",
        en: "No recent originals yet — shoot or import a photo and it'll appear here",
        ja: "まだ履歴がありません。撮影または読み込むとここに残ります",
        ko: "아직 최근 사진이 없어요 — 촬영하거나 불러오면 여기에 보관됩니다",
        fr: "Aucune photo récente — prenez ou importez une photo pour la retrouver ici",
        de: "Noch keine Aufnahmen — nach dem Fotografieren oder Importieren erscheinen sie hier",
        it: "Nessuna foto recente — scatta o importa una foto per ritrovarla qui")
    static let clearHistory = Loc8(zh: "清空全部", zhTW: "清空全部", en: "Clear all",
        ja: "すべて削除", ko: "모두 삭제", fr: "Tout effacer", de: "Alle löschen", it: "Cancella tutto")
    static let deleteItem = Loc8(zh: "删除", zhTW: "刪除", en: "Delete",
        ja: "削除", ko: "삭제", fr: "Supprimer", de: "Löschen", it: "Elimina")

    // Spec picker
    static let chooseDoc = Loc8(zh: "选择证件", zhTW: "選擇證件", en: "Choose document",
        ja: "証明書を選択", ko: "문서 선택", fr: "Choisir le document",
        de: "Dokument wählen", it: "Scegli documento")
    static let cancel = Loc8(zh: "取消", zhTW: "取消", en: "Cancel", ja: "キャンセル", ko: "취소",
        fr: "Annuler", de: "Abbrechen", it: "Annulla")
    static let searchSpecs = Loc8(zh: "搜索国家、证件或尺寸 (如 35x45)", zhTW: "搜尋國家、證件或尺寸 (如 35x45)",
        en: "Search country, document, or size (e.g. 35x45)", ja: "国名・証明書・サイズで検索",
        ko: "국가, 문서 또는 크기 검색 (예: 35x45)", fr: "Rechercher pays, document ou taille",
        de: "Land, Dokument oder Größe suchen", it: "Cerca paese, documento o formato")
    static let customSize = Loc8(zh: "自定义尺寸 (毫米 / 文件大小限制)", zhTW: "自訂尺寸 (公釐 / 檔案大小限制)",
        en: "Custom size (mm & file size limit)", ja: "カスタムサイズ (mm・ファイル容量上限)",
        ko: "사용자 지정 크기 (mm 및 파일 크기 제한)", fr: "Taille personnalisée (mm et poids max)",
        de: "Benutzerdefinierte Größe (mm & Dateigröße)", it: "Formato personalizzato (mm e peso max)")
    static let widthMM = Loc8(zh: "宽 (mm)", zhTW: "寬 (mm)", en: "Width (mm)", ja: "幅 (mm)",
        ko: "가로 (mm)", fr: "Largeur (mm)", de: "Breite (mm)", it: "Larghezza (mm)")
    static let heightMM = Loc8(zh: "高 (mm)", zhTW: "高 (mm)", en: "Height (mm)", ja: "高さ (mm)",
        ko: "세로 (mm)", fr: "Hauteur (mm)", de: "Höhe (mm)", it: "Altezza (mm)")
    static let maxKBLabel = Loc8(zh: "最大 KB (选填)", zhTW: "最大 KB (選填)", en: "Max KB (optional)",
        ja: "最大 KB (任意)", ko: "최대 KB (선택)", fr: "Ko max (optionnel)",
        de: "Max. KB (optional)", it: "KB max (opz.)")
    static let useCustomSize = Loc8(zh: "使用该尺寸", zhTW: "使用該尺寸", en: "Use custom size",
        ja: "このサイズを使う", ko: "이 크기 사용", fr: "Utiliser cette taille",
        de: "Größe verwenden", it: "Usa questo formato")

    // Import from the photo library
    static let choosePhoto = Loc8(zh: "从相册选择", zhTW: "從相簿選擇", en: "Choose photo",
        ja: "写真から選ぶ", ko: "앨범에서 선택", fr: "Choisir une photo",
        de: "Foto wählen", it: "Scegli foto")
    static let importing = Loc8(zh: "处理中…", zhTW: "處理中…", en: "Processing…", ja: "処理中…",
        ko: "처리 중…", fr: "Traitement…", de: "Verarbeiten…", it: "Elaborazione…")
    static let importNoFace = Loc8(zh: "这张照片里没找到人脸，换一张试试",
        zhTW: "這張照片裡沒找到人臉，換一張試試", en: "No face found in that photo — try another one",
        ja: "この写真では顔を検出できませんでした。別の写真をお試しください",
        ko: "이 사진에서 얼굴을 찾지 못했어요 — 다른 사진을 골라 주세요",
        fr: "Aucun visage détecté sur cette photo — essayez-en une autre",
        de: "Kein Gesicht in diesem Foto gefunden — probiere ein anderes",
        it: "Nessun volto in questa foto — provane un'altra")
    static let importManyFaces = Loc8(zh: "照片里不止一个人，换一张只有你的",
        zhTW: "照片裡不只一個人，換一張只有你的", en: "More than one person in that photo — pick one with just you",
        ja: "写真に複数の人物がいます。一人だけの写真を選んでください",
        ko: "사진에 여러 사람이 있어요 — 혼자 나온 사진을 골라 주세요",
        fr: "Plusieurs personnes sur cette photo — choisissez-en une avec vous seul",
        de: "Mehr als eine Person auf dem Foto — wähle eines nur mit dir",
        it: "Più di una persona nella foto — scegline una con te soltanto")
    static let importUnreadable = Loc8(zh: "这张照片读不出来，换一张试试",
        zhTW: "這張照片讀不出來，換一張試試", en: "Couldn't read that photo — try another one",
        ja: "この写真を読み込めませんでした。別の写真をお試しください",
        ko: "이 사진을 읽을 수 없어요 — 다른 사진을 골라 주세요",
        fr: "Impossible de lire cette photo — essayez-en une autre",
        de: "Foto konnte nicht gelesen werden — probiere ein anderes",
        it: "Impossibile leggere la foto — provane un'altra")

    // Honest verdict on an imported photo (things the export can't fix for you)
    static let checkBeforeYouSubmit = Loc8(zh: "提交前请注意", zhTW: "提交前請注意",
        en: "Check before you submit", ja: "提出前にご確認ください", ko: "제출 전 확인하세요",
        fr: "À vérifier avant l'envoi", de: "Vor dem Einreichen prüfen",
        it: "Controlla prima di inviare")
    static let issuePose = Loc8(zh: "头有点歪或侧着，要正对镜头", zhTW: "頭有點歪或側著，要正對鏡頭",
        en: "Head is turned or tilted — it should face straight ahead",
        ja: "顔が傾いています。正面を向いてください", ko: "얼굴이 기울었어요 — 정면을 봐야 해요",
        fr: "Tête tournée ou inclinée — elle doit être de face",
        de: "Kopf gedreht oder geneigt — er sollte gerade nach vorn zeigen",
        it: "Testa girata o inclinata — deve guardare dritto")
    static let issueEyes = Loc8(zh: "眼睛要睁开并看向镜头", zhTW: "眼睛要睜開並看向鏡頭",
        en: "Eyes must be open and looking at the camera",
        ja: "目を開けてカメラを見てください", ko: "눈을 뜨고 카메라를 봐야 해요",
        fr: "Les yeux doivent être ouverts et regarder l'objectif",
        de: "Augen müssen offen sein und in die Kamera blicken",
        it: "Occhi aperti e rivolti all'obiettivo")
    static let issueExpression = Loc8(zh: "表情要自然，嘴巴闭上不露齿笑", zhTW: "表情要自然，嘴巴閉上不露齒笑",
        en: "Keep a neutral expression — mouth closed, no big smile",
        ja: "口を閉じ、歯を見せず自然な表情にしてください", ko: "입을 다물고 웃지 않는 자연스러운 표정이어야 해요",
        fr: "Expression neutre, bouche fermée sans grand sourire",
        de: "Neutraler Ausdruck, Mund geschlossen ohne breites Lächeln",
        it: "Espressione neutra, bocca chiusa senza sorriso")
    static let issueGlasses = Loc8(zh: "眼镜不符合要求（有镜片反光或该摘下眼镜）",
        zhTW: "眼鏡不符合要求（有鏡片反光或該摘下眼鏡）", en: "Glasses are a problem here — lens glare, or not allowed",
        ja: "眼鏡に問題があります（レンズの反射、または着用不可）",
        ko: "안경이 문제예요 — 빛 반사가 있거나 착용이 불가해요",
        fr: "Problème de lunettes — reflets sur les verres, ou interdites",
        de: "Brille ist ein Problem — Spiegelung auf Gläsern oder verboten",
        it: "Problema con gli occhiali — riflessi sulle lenti o vietati")
    static let issueLighting = Loc8(zh: "整体光线太暗或太亮", zhTW: "整體光線太暗或太亮",
        en: "Overall lighting is too dark or too bright", ja: "全体が明るすぎるか暗すぎます",
        ko: "전체 조명이 너무 어둡거나 밝아요", fr: "Éclairage global trop sombre ou trop clair",
        de: "Gesamtbeleuchtung zu dunkel oder zu hell", it: "Illuminazione complessiva troppo scura o chiara")
    static let issueFaceLighting = Loc8(zh: "面部左右光线不均（避免侧光阴影）", zhTW: "臉部左右光線不均（避免側光陰影）",
        en: "Uneven shadow across face — face the light evenly",
        ja: "顔の左右で明るさに差があります。正面から光を受けてください",
        ko: "얼굴 좌우 밝기가 달라요 — 조명을 정면으로 마주 보세요",
        fr: "Ombre latérale sur le visage — placez-vous face à la lumière",
        de: "Ungleichmäßiger Schatten im Gesicht — frontal zum Licht stellen",
        it: "Ombra laterale sul viso — mettiti di fronte alla luce")
    static let issueBackground = Loc8(zh: "背景不符合要求，需要干净均匀的底色",
        zhTW: "背景不符合要求，需要乾淨均勻的底色",
        en: "Background doesn't meet the rule — it needs to be plain and even",
        ja: "背景が要件を満たしていません。無地で均一な背景が必要です",
        ko: "배경이 규정에 맞지 않아요 — 단색의 균일한 배경이 필요해요",
        fr: "Le fond ne respecte pas la règle — il doit être uni et régulier",
        de: "Hintergrund erfüllt die Regel nicht — er muss schlicht und gleichmäßig sein",
        it: "Lo sfondo non rispetta la regola — dev'essere uniforme")
    static let issueFraming = Loc8(zh: "这张照片裁不出合规构图：脸离边太近，或在画面里过大/过小",
        zhTW: "這張照片裁不出合規構圖：臉離邊太近，或在畫面裡過大/過小",
        en: "This photo can't be framed to spec — the face is too near an edge, or too large/small in frame",
        ja: "この写真は規格の構図に収まりません。顔が端に近すぎるか、大きすぎ/小さすぎます",
        ko: "이 사진은 규격 구도로 자를 수 없어요 — 얼굴이 가장자리에 너무 가깝거나 너무 크거나 작아요",
        fr: "Impossible de cadrer cette photo — le visage est trop près d'un bord, ou trop grand/petit",
        de: "Dieses Foto lässt sich nicht normgerecht zuschneiden — Gesicht zu nah am Rand oder zu groß/klein",
        it: "Questa foto non si può inquadrare a norma — volto troppo vicino al bordo o troppo grande/piccolo")

    // Print sheet
    static let printSheet = Loc8(zh: "打印排版", zhTW: "列印排版", en: "Print sheet",
        ja: "プリント用シート", ko: "인화용 시트", fr: "Planche à imprimer",
        de: "Druckbogen", it: "Foglio di stampa")
    static let printSheetNote = Loc8(
        zh: "把多张照片拼到一张相纸上，拿去冲印店或自己打印。",
        zhTW: "把多張照片拼到一張相紙上，拿去沖印店或自己列印。",
        en: "Tiles copies onto one sheet of photo paper for a print shop or your own printer.",
        ja: "1 枚の印画紙に複数枚を並べます。写真店や自宅のプリンターで印刷できます。",
        ko: "한 장의 인화지에 여러 장을 배치합니다. 사진관이나 집 프린터에서 인쇄하세요.",
        fr: "Assemble plusieurs copies sur une feuille, pour un labo photo ou votre imprimante.",
        de: "Legt mehrere Kopien auf einen Bogen — fürs Fotolabor oder den eigenen Drucker.",
        it: "Dispone più copie su un foglio, per il laboratorio o la tua stampante.")
    static let copiesFormat = Loc8(zh: "%d 张", zhTW: "%d 張", en: "%d copies", ja: "%d 枚",
        ko: "%d장", fr: "%d copies", de: "%d Kopien", it: "%d copie")
    static let sheetFailed = Loc8(zh: "排版失败，请重试", zhTW: "排版失敗，請重試",
        en: "Couldn't build the sheet — try again", ja: "シートを作成できませんでした",
        ko: "시트를 만들지 못했어요 — 다시 시도하세요",
        fr: "Impossible de créer la planche — réessayez",
        de: "Bogen konnte nicht erstellt werden — erneut versuchen",
        it: "Impossibile creare il foglio — riprova")
}

/// Localized country / document-type / color names, composed for spec rows.
enum SpecText {
    static func country(_ code: String) -> Loc8 {
        switch code.uppercased() {
        case "CN": return Loc8(zh: "中国", zhTW: "中國大陸", en: "China", ja: "中国", ko: "중국", fr: "Chine", de: "China", it: "Cina")
        case "HK": return Loc8(zh: "中国香港", zhTW: "香港", en: "Hong Kong", ja: "香港", ko: "홍콩", fr: "Hong Kong", de: "Hongkong", it: "Hong Kong")
        case "TW": return Loc8(zh: "中国台湾", zhTW: "台灣", en: "Taiwan", ja: "台湾", ko: "대만", fr: "Taïwan", de: "Taiwan", it: "Taiwan")
        case "US": return Loc8(zh: "美国", zhTW: "美國", en: "United States", ja: "アメリカ", ko: "미국", fr: "États-Unis", de: "USA", it: "Stati Uniti")
        case "CA": return Loc8(zh: "加拿大", zhTW: "加拿大", en: "Canada", ja: "カナダ", ko: "캐나다", fr: "Canada", de: "Kanada", it: "Canada")
        case "AU": return Loc8(zh: "澳大利亚", zhTW: "澳洲", en: "Australia", ja: "オーストラリア", ko: "호주", fr: "Australie", de: "Australien", it: "Australia")
        case "GB", "UK": return Loc8(zh: "英国", zhTW: "英國", en: "United Kingdom", ja: "イギリス", ko: "영국", fr: "Royaume-Uni", de: "Vereinigtes Königreich", it: "Regno Unito")
        case "KR": return Loc8(zh: "韩国", zhTW: "韓國", en: "South Korea", ja: "韓国", ko: "대한민국", fr: "Corée du Sud", de: "Südkorea", it: "Corea del Sud")
        case "IN": return Loc8(zh: "印度", zhTW: "印度", en: "India", ja: "インド", ko: "인도", fr: "Inde", de: "Indien", it: "India")
        case "JP": return Loc8(zh: "日本", zhTW: "日本", en: "Japan", ja: "日本", ko: "일본", fr: "Japon", de: "Japan", it: "Giappone")
        case "SG": return Loc8(zh: "新加坡", zhTW: "新加坡", en: "Singapore", ja: "シンガポール", ko: "싱ガ포르".replacingOccurrences(of: "ガ", with: "가"), fr: "Singapour", de: "Singapur", it: "Singapore")
        case "EU": return Loc8(zh: "申根", zhTW: "申根", en: "Schengen", ja: "シェンゲン", ko: "솅겐", fr: "Schengen", de: "Schengen", it: "Schengen")
        case "CUSTOM": return Loc8(zh: "自定义", zhTW: "自訂", en: "Custom", ja: "カスタム", ko: "사용자 지정", fr: "Personnalisé", de: "Benutzerdefiniert", it: "Personalizzato")
        default: return Loc8(zh: code, zhTW: code, en: code, ja: code, ko: code, fr: code, de: code, it: code)
        }
    }

    static func docType(_ type: DocType) -> Loc8 {
        switch type {
        case .passport: return Loc8(zh: "护照", zhTW: "護照", en: "Passport", ja: "パスポート", ko: "여권", fr: "Passeport", de: "Reisepass", it: "Passaporto")
        case .visa: return Loc8(zh: "签证", zhTW: "簽證", en: "Visa", ja: "ビザ", ko: "비자", fr: "Visa", de: "Visum", it: "Visto")
        case .idCard: return Loc8(zh: "身份证", zhTW: "身分證", en: "ID Card", ja: "IDカード", ko: "신분증", fr: "Carte d'identité", de: "Ausweis", it: "Carta d'identità")
        case .driverLicense: return Loc8(zh: "驾驶证", zhTW: "駕照", en: "Driver License", ja: "運転免許", ko: "운전면허", fr: "Permis", de: "Führerschein", it: "Patente")
        case .residencePermit: return Loc8(zh: "通行证 / 居留", zhTW: "通行證 / 居留", en: "Travel / Residence Permit", ja: "通行証・在留許可", ko: "통행증 / 체류허가", fr: "Titre de séjour", de: "Aufenthaltstitel", it: "Permesso di soggiorno")
        case .general: return Loc8(zh: "证件照", zhTW: "證件照", en: "ID Photo", ja: "証明写真", ko: "증명사진", fr: "Photo d'identité", de: "Passfoto", it: "Foto tessera")
        }
    }

    /// Specific 8-language titles for specs where generic `country + docType` would lose the
    /// exact document distinction (e.g. Social Security vs Resident ID, CET/Teacher Exam vs 1-inch).
    private static func specificTitle(_ id: String) -> Loc8? {
        switch id {
        case "cn-1inch":
            return Loc8(zh: "中国 一寸证件照 (25×35)", zhTW: "中國 一吋證件照 (25×35)", en: "China 1-inch ID (25×35)",
                        ja: "中国 1寸証明写真 (25×35)", ko: "중국 1인치 증명사진 (25×35)",
                        fr: "Chine Photo 1 pouce (25×35)", de: "China 1-Zoll-Foto (25×35)", it: "Cina Foto 1 pollice (25×35)")
        case "cn-2inch":
            return Loc8(zh: "中国 二寸证件照 (35×49)", zhTW: "中國 二吋證件照 (35×49)", en: "China 2-inch ID (35×49)",
                        ja: "中国 2寸証明写真 (35×49)", ko: "중국 2인치 증명사진 (35×49)",
                        fr: "Chine Photo 2 pouces (35×49)", de: "China 2-Zoll-Foto (35×49)", it: "Cina Foto 2 pollici (35×49)")
        case "cn-idcard":
            return Loc8(zh: "中国 居民身份证", zhTW: "中國 居民身分證", en: "China Resident ID Card",
                        ja: "中国 居民身分証", ko: "중국 주민신분증",
                        fr: "Chine Carte d'identité", de: "China Personalausweis", it: "Cina Carta d'identità")
        case "cn-social":
            return Loc8(zh: "中国 社保卡 / 医保卡", zhTW: "中國 社保卡 / 醫保卡", en: "China Social Security Card",
                        ja: "中国 社会保障カード", ko: "중국 사회보장카드",
                        fr: "Chine Carte sécurité sociale", de: "China Sozialversicherungskarte", it: "Cina Tessera previdenziale")
        case "cn-driver":
            return Loc8(zh: "中国 机动车驾驶证", zhTW: "中國 機動車駕駛證", en: "China Driver License",
                        ja: "中国 運転免許証", ko: "중국 운전면허증",
                        fr: "Chine Permis de conduire", de: "China Führerschein", it: "Cina Patente di guida")
        case "cn-exam":
            return Loc8(zh: "中国 四六级 / 教资 / 公考报名照", zhTW: "中國 四六級 / 教資 / 公考報名照", en: "China Exam (CET / Teacher / Civil)",
                        ja: "中国 資格・試験申込写真", ko: "중국 자격증·공무원 시험 사진",
                        fr: "Chine Photo d'examen officiel", de: "China Prüfungsfoto", it: "Cina Foto per esami pubblici")
        case "cn-grad":
            return Loc8(zh: "中国 学信网 / 毕业证采集 (480×640)", zhTW: "中國 學信網 / 畢業證採集 (480×640)", en: "China CHSI Graduation (480×640)",
                        ja: "中国 学信網・卒業証書 (480×640)", ko: "중국 학신망 졸업사진 (480×640)",
                        fr: "Chine Diplôme CHSI (480×640)", de: "China Abschlussfoto CHSI (480×640)", it: "Cina Foto laurea CHSI (480×640)")
        case "cn-hkmo":
            return Loc8(zh: "中国 往来港澳台通行证", zhTW: "中國 往來港澳台通行證", en: "HK / Macau / Taiwan Travel Permit",
                        ja: "香港・マカオ・台湾往来通行証", ko: "홍콩·마카오·대만 통행증",
                        fr: "Permis voyage HK / Macao / Taïwan", de: "Reisegenehmigung HK / Macau / Taiwan", it: "Permesso viaggio HK / Macao / Taiwan")
        case "hk-passport":
            return Loc8(zh: "中国香港 特区护照 / 回乡证", zhTW: "香港 特區護照 / 回鄉證", en: "Hong Kong SAR Passport",
                        ja: "香港特別行政区パスポート", ko: "홍콩 특별행정구 여권",
                        fr: "Passeport RAS de Hong Kong", de: "Reisepass Hongkong", it: "Passaporto Hong Kong")
        case "tw-passport":
            return Loc8(zh: "中国台湾 护照 / 入台证", zhTW: "台灣 護照 / 入台證", en: "Taiwan Passport / Entry Permit",
                        ja: "台湾パスポート・入台証", ko: "대만 여권 / 입대증",
                        fr: "Passeport Taïwan", de: "Reisepass Taiwan", it: "Passaporto Taiwan")
        case "jp-resume":
            return Loc8(zh: "日本 履历书 / 在留卡 (30×40)", zhTW: "日本 履歷書 / 在留卡 (30×40)", en: "Japan Resume / Residence Card (30×40)",
                        ja: "日本 履歴書・在留カード (30×40)", ko: "일본 이력서·재류카드 (30×40)",
                        fr: "Japon CV / Carte de séjour (30×40)", de: "Japan Lebenslauf / Aufenthaltskarte", it: "Giappone CV / Carta di soggiorno")
        default:
            return nil
        }
    }

    /// Localized human-readable title for a spec.
    static func name(_ spec: PhotoSpec) -> String {
        if let specific = specificTitle(spec.id) {
            return specific.t
        }
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
        if h == "#438EDB" || h == "#3366CC" {
            return Loc8(zh: "蓝色", zhTW: "藍色", en: "blue", ja: "青", ko: "파란색", fr: "bleu", de: "blauen", it: "blu").t
        }
        if h == "#D9001B" {
            return Loc8(zh: "红色", zhTW: "紅色", en: "red", ja: "赤", ko: "빨간색", fr: "rouge", de: "roten", it: "rosso").t
        }
        // EDEDED / ECECEC and other light grays
        return Loc8(zh: "浅灰白", zhTW: "淺灰白", en: "off-white", ja: "オフホワイト", ko: "연회색",
                    fr: "gris clair", de: "hellgrauen", it: "grigio chiaro").t
    }
}
