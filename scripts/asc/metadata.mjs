// All App Store metadata for FreeID Photo, in one editable place.
// release.mjs applies this every run, so a brand-new version inherits it too.
// App Store locale codes: en-US, zh-Hans, zh-Hant, ja, ko, fr-FR, de-DE, it.

// App-level info localizations: name (≤30 chars) + subtitle (≤30 chars) + privacy policy URL.
// Guideline 2.3.7: describe what the app does; never put price claims ("free") in subtitle.
// Every locale listed here MUST also have a matching entry in `versionLocalizations` below.
export const appInfoLocalizations = {
  'en-US':   { name: 'FreeID Photo: Passport & ID',   subtitle: 'On-device ID photo maker',       privacyPolicyUrl: 'https://doaipm.com/privacy' },
  'zh-Hans': { name: 'FreeID 证件照 · 护照签证照',    subtitle: '本地处理不上传 · 打印排版',      privacyPolicyUrl: 'https://doaipm.com/privacy' },
  'zh-Hant': { name: 'FreeID 證件照 · 護照簽證照',    subtitle: '本機處理不上傳 · 列印排版',      privacyPolicyUrl: 'https://doaipm.com/privacy' },
  'ja':      { name: 'FreeID 証明写真・パスポート',    subtitle: '端末内で作る証明写真・履歴書',   privacyPolicyUrl: 'https://doaipm.com/privacy' },
  'ko':      { name: 'FreeID 증명사진 · 여권 비자',    subtitle: '기기 내 처리 · 인화 시트 제작',  privacyPolicyUrl: 'https://doaipm.com/privacy' },
  'fr-FR':   { name: 'FreeID Photo Passeport & ID',   subtitle: "Photos d'identité hors ligne",   privacyPolicyUrl: 'https://doaipm.com/privacy' },
  'de-DE':   { name: 'FreeID Passfoto & Ausweis',     subtitle: 'Biometrische Fotos auf Gerät',   privacyPolicyUrl: 'https://doaipm.com/privacy' },
  'it':      { name: 'FreeID Foto Tessera & Visto',   subtitle: 'Foto tessera sul dispositivo',   privacyPolicyUrl: 'https://doaipm.com/privacy' },
};

// Version localizations: description (≤4000), keywords (≤100 chars), promotionalText (≤170),
// support/marketing URL, and whatsNew (release notes — required for updates).
export const versionLocalizations = {
  'en-US': {
    description: `FreeID Photo makes a compliant passport, visa, or ID photo on your iPhone in seconds — no watermark, no account, nothing uploaded.

• 24 official specs across 12 countries & regions (US, UK, Schengen, Canada, Australia, China, Hong Kong, Taiwan, Japan, South Korea, India, Singapore) plus custom millimetre sizes & max KB limits.
• Real-time compliance checks: head size, eye line, pose, glasses & lens glare, even left/right face lighting, and neutral expression.
• Per-country edit rules: strict countries (US, UK, Canada) stay unedited; where allowed, swap backgrounds (white / blue / red) and gently adjust brightness or natural skin tone.
• Recent originals stay locally on your device — re-export a previous shot in any new spec with one tap.
• Front or back camera with spoken voice guidance & auto-shutter, plus 4×6", 5×7", and A4 print sheets with cut guides.

Everything runs 100% on-device. Nothing is uploaded.`,
    keywords: 'passport photo,id photo,visa photo,headshot,biometric,2x2,background,print sheet,driver license,exam',
    promotionalText: 'On-device passport, visa & ID photos across 24 global specs — no watermark, no account, nothing uploaded.',
    whatsNew: `• Expanded to 24 official specs across 12 countries/regions (driver license, social security, academic & civil exams, HK/Taiwan passports, Japan resume).
• Smarter compliance checks: glasses & lens-glare detection, left/right facial shadow check, and neutral-expression guidance.
• Result screen upgrades: instant spec switching, local history originals for 1-tap re-export, plus gentle brightness & natural skin refinement where allowed.
• Full store localization across 8 languages.`,
    supportUrl: 'https://doaipm.com', marketingUrl: 'https://doaipm.com',
  },
  'zh-Hans': {
    description: `FreeID Photo 在 iPhone 上几秒做好一张合规的证件照、护照或考试报名照 —— 无水印、无需注册、全程本地不上传。

• 覆盖 12 个国家/地区共 24 种常用规格（一寸、二寸、居民身份证、驾驶证、社保卡、四六级/教资/公考报名照、学信网毕业采集、港澳台通行证、美国/英国/申根/日本/韩国护照签证等），并支持自定义毫米尺寸与文件大小（KB）上限。
• 智能合规检测：头部比例、眼线位置、姿态端正、眼镜与镜片反光、面部左右阴阳脸光照均匀度、自然表情提醒。
• 按国家区分修图规则：美英等严禁修图的国家保持真实原片裁切；允许修图的证件支持一键换底色（白/蓝/红）以及自然亮度与肤质微调。
• 本地历史原片夹：拍过一次留存在本机，下次换考公、驾照或签证尺寸一键重新导出，无需重拍。
• 支持后置镜头语音引导与自动快门，以及 4×6 寸、5×7 寸、A4 冲印排版。

全部在设备本地完成，不上传任何照片数据。`,
    keywords: '证件照,护照照片,签证照,一寸照,二寸照,驾驶证,社保卡,四六级,学信网,换底色,白底,蓝底,打印排版',
    promotionalText: '覆盖 24 种国内外证件与考试规格，全程设备本地处理，无水印、不上传、支持冲印排版。',
    whatsNew: `• 新增驾驶证、社保卡、四六级/教资/公考报名照、学信网采集（480×640）、港澳台通行证、香港与台湾护照、日本履历书等 8 种高频规格（共 24 种）。
• 合规检测升级：新增眼镜与镜片反光识别、面部左右光线均匀度（防阴阳脸）及露齿笑表情检测。
• 结果页与历史原片夹：支持在结果页直接切换规格重导出、本地历史原片一键复用，以及允许修图规格下的亮度与自然肤质微调。`,
    supportUrl: 'https://doaipm.com', marketingUrl: 'https://doaipm.com',
  },
  'zh-Hant': {
    description: `FreeID Photo 在 iPhone 上幾秒鐘製作合規的證件照、護照或簽證照片 —— 無浮水印、免註冊、全程本機處理不上傳。

• 內建 12 個國家/地區共 24 種官方規格（台灣護照/入台證、香港特區護照/回鄉證、往來港澳台通行證、美國/英國/日本/韓國/申根/加拿大/澳洲護照簽證、1吋/2吋等），亦支援自訂公釐尺寸與檔案 KB 上限。
• 智慧合規檢查：頭部比例、眼線高度、姿勢端正、眼鏡與鏡片反光、臉部左右受光均勻度及自然表情提示。
• 依國家區分修圖規範：嚴禁修圖之國家保留真實背景裁切；允許修圖之證件支援一鍵換底色（白/藍/紅）及自然亮度與膚質微調。
• 本機歷史原片夾：原片僅存於手機本機，隨時一鍵換規格重新匯出，並支援 4×6、5×7 與 A4 列印排版。

所有運算均在您的裝置上離線完成，絕不上傳任何照片。`,
    keywords: '證件照,護照照片,簽證照,台灣護照,香港護照,入台證,回鄉證,一吋照,二吋照,換背景,白底,列印排版',
    promotionalText: '內建 24 種全球護照與證件照規格，100% 本機離線處理、無浮水印、支援列印排版。',
    whatsNew: `• 擴充至 12 個地區共 24 種規格，新增香港特區護照、台灣護照/入台證、日本履歷書、駕照與考試照等常用尺寸。
• 合規檢測升級：新增眼鏡與鏡片反光偵測、臉部左右光線均勻度檢查與自然表情提示。
• 結果頁新增一鍵換規格重匯出、本機歷史原片夾，以及亮度與自然膚質微調功能。`,
    supportUrl: 'https://doaipm.com', marketingUrl: 'https://doaipm.com',
  },
  'ja': {
    description: `FreeID Photo は、パスポート・ビザ・履歴書・在留カードなどの証明写真を iPhone だけで数秒で作成できるアプリです。透かしなし、アカウント登録不要、サーバーへのアップロードも一切ありません。

• 12の国と地域・24種類の公式規格に対応（日本ビザ、履歴書・在留カード・運転免許 30×40mm、米国・英国・シェンゲン・韓国・中国・台湾・香港など）。ミリ単位のカスタムサイズやファイル容量（KB）上限の指定も可能。
• AI コンプライアンス判定：頭のサイズ、目の高さ、顔の傾き、眼鏡やレンズの反射、左右の顔の明るさムラ、自然な表情をチェック。
• 国ごとの加工ルールに対応：加工禁止国（米国・英国など）は無加工で正確にトリミング。背景変更が可能な書類では白・青・赤の背景切り替えや自然な明るさ・肌補正に対応。
• 端末内の撮影履歴からいつでも別サイズで再出力。L判に近い 4×6・5×7・A4 プリント用シート作成にも対応。`,
    keywords: '証明写真,パスポート写真,履歴書写真,ビザ写真,マイナンバー,在留カード,運転免許,背景変更,白背景,コンビニ印刷',
    promotionalText: '履歴書・パスポート・ビザなど24規格に対応。すべて端末内で完結し、透かしなし・アップロード不要。',
    whatsNew: `• 日本の履歴書・在留カード（30×40mm）を含む12地域・24種類の規格に拡大。
• 眼鏡・レンズ反射の検出、顔の左右の明るさムラ判定、自然な表情チェックを追加。
• 結果画面でのサイズ即時切り替え、端末内の撮影履歴からの再出力、自然な明るさ・肌補正機能を追加。`,
    supportUrl: 'https://doaipm.com', marketingUrl: 'https://doaipm.com',
  },
  'ko': {
    description: `FreeID Photo는 아이폰에서 몇 초 만에 규격에 맞는 여권, 비자, 증명사진을 만들어 주는 온디바이스 앱입니다 — 워터마크 없음, 회원가입 없음, 서버 업로드 없음.

• 12개 국가/지역 24종 공식 규격 지원(대한민국 여권, 미국 비자/여권 2×2, 일본 비자/이력서, 중국/유럽 솅겐/영국/캐나다/호주 등) 및 사용자 지정 mm 크기·최대 KB 용량 설정 지원.
• 실시간 규격 검사: 머리 크기, 눈 위치, 정면 자세, 안경 착용 및 빛 반사, 얼굴 좌우 조명 균형, 자연스러운 표정 안내.
• 국가별 편집 정책 준수: 디지털 편집을 금지하는 국가(한국·미국·영국 여권 등)는 원본 그대로 정밀 크롭하며, 허용되는 일반 증명사진은 배경색(흰색/파랑/빨강) 변경과 자연스러운 밝기·피부 보정을 지원합니다.
• 기기에만 저장되는 최근 원본함으로 언제든 다른 규격으로 즉시 재추출하고, 4×6·5×7·A4 인화용 시트로 출력할 수 있습니다.`,
    keywords: '증명사진,여권사진,비자사진,반명함,이력서사진,운전면허,신분증사진,배경제거,흰색배경,인화시트',
    promotionalText: '24종 글로벌 여권·비자·증명사진 규격 지원. 워터마크와 서버 업로드 없이 기기 내에서 안전하게 제작하세요.',
    whatsNew: `• 12개국 24종 규격으로 확대 및 결과 화면에서 즉시 규격 변경 지원.
• 안경 및 렌즈 빛 반사 감지, 얼굴 좌우 그림자 균형 검사, 자연스러운 표정 체크 추가.
• 기기 내 최근 원본 보관함 및 허용 규격용 자연스러운 밝기·피부 보정 슬라이더 추가.`,
    supportUrl: 'https://doaipm.com', marketingUrl: 'https://doaipm.com',
  },
  'fr-FR': {
    description: `FreeID Photo crée une photo d'identité, de passeport ou de visa conforme en quelques secondes sur votre iPhone — sans filigrane, sans compte et sans aucun envoi sur un serveur.

• 24 formats officiels dans 12 pays et régions (Schengen / UE 35×45 mm, États-Unis, Royaume-Uni, Canada, Australie, Japon, Corée, Chine, etc.) ainsi que formats personnalisés en mm et limite en Ko.
• Contrôle de conformité intelligent : taille de la tête, hauteur des yeux, posture, lunettes et reflets sur les verres, éclairage équilibré du visage et expression neutre.
• Respect des règles par pays : recadrage pur sans retouche pour les pays stricts (États-Unis, Royaume-Uni) ; fond uni (blanc / bleu / rouge) et ajustement léger de luminosité là où c'est autorisé.
• Historique local sur l'appareil pour réexporter une prise dans un autre format en un geste, et planches d'impression 10×15 cm (4×6"), 5×7" et A4.`,
    keywords: 'photo identité,passeport,visa,schengen,35x45,permis,biométrique,fond blanc,planche photo,cv',
    promotionalText: "Photos d'identité, passeport et visa 100 % sur l'appareil — 24 formats officiels, sans filigrane ni upload.",
    whatsNew: `• Extension à 24 formats officiels dans 12 pays et régions.
• Détection des lunettes et reflets, vérification de l'éclairage latéral du visage et de l'expression neutre.
• Changement instantané de format sur l'écran résultat, historique local sur l'appareil et réglage doux de luminosité.`,
    supportUrl: 'https://doaipm.com', marketingUrl: 'https://doaipm.com',
  },
  'de-DE': {
    description: `FreeID Photo erstellt in Sekunden ein biometrisches Passfoto, Visumfoto oder Bewerbungsfoto direkt auf Ihrem iPhone — ohne Wasserzeichen, ohne Konto und ohne Cloud-Upload.

• 24 offizielle Formate aus 12 Ländern & Regionen (Schengen / EU 35×45 mm, USA, Großbritannien, Kanada, Australien, Japan, Südkorea, China u. a.) sowie eigene Millimeter-Maße und maximale KB-Dateigröße.
• Intelligente Biometrie-Prüfung: Kopfhöhe, Augenlinie, Kopfhaltung, Brillen- und Glasreflex-Erkennung, gleichmäßige Gesichtsausleuchtung und neutraler Gesichtsausdruck.
• Länderspezifische Bearbeitungsregeln: Unbearbeiteter Zuschnitt für strenge Länder (z. B. USA, UK); Hintergrundwechsel (Weiß / Blau / Rot) sowie dezente Helligkeits- und Hautanpassung, wo erlaubt.
• Lokaler Verlauf auf dem Gerät zum sofortigen Neu-Export in andere Formate sowie Druckbögen in 10×15 cm (4×6"), 5×7" und A4.`,
    keywords: 'passfoto,biometrisch,ausweis,reisepass,visum,35x45,bewerbungsfoto,führerschein,druckbogen',
    promotionalText: 'Biometrische Pass- & Visumfotos komplett lokal auf dem iPhone — 24 Formate, kein Wasserzeichen, kein Upload.',
    whatsNew: `• Erweitert auf 24 offizielle Formate in 12 Ländern & Regionen.
• Neue Prüfung auf Brillen/Glasreflexe, seitliche Gesichtsschatten und neutralen Ausdruck.
• Sofortiger Formatwechsel auf dem Ergebnisbildschirm, lokaler Original-Verlauf und dezente Helligkeitsanpassung.`,
    supportUrl: 'https://doaipm.com', marketingUrl: 'https://doaipm.com',
  },
  'it': {
    description: `FreeID Photo crea in pochi secondi una foto tessera, passaporto o visto conforme direttamente sul tuo iPhone — senza filigrana, senza registrazione e senza caricare nulla online.

• 24 formati ufficiali per 12 paesi e regioni (Schengen / UE 35×45 mm, Stati Uniti, Regno Unito, Canada, Australia, Giappone, Corea, Cina e altri), oltre a misure personalizzate in mm e limite in KB.
• Verifica biometrica intelligente: dimensioni della testa, linea degli occhi, postura, rilevamento occhiali e riflessi sulle lenti, illuminazione uniforme del viso ed espressione neutra.
• Regole per singolo paese: ritaglio puro senza modifiche per i paesi restrittivi (USA, UK); cambio sfondo (bianco / blu / rosso) e leggera regolazione di luminosità dove consentito.
• Cronologia locale sul dispositivo per riesportare uno scatto in un nuovo formato con un tocco, più fogli di stampa 10×15 cm (4×6"), 5×7" e A4.`,
    keywords: 'foto tessera,passaporto,visto,carta identità,patente,biometrica,35x45,sfondo bianco,stampa',
    promotionalText: 'Foto tessera, passaporto e visto elaborate sul dispositivo — 24 formati ufficiali, zero filigrane, zero upload.',
    whatsNew: `• Espanso a 24 formati ufficiali in 12 paesi e regioni.
• Nuovo controllo di occhiali e riflessi sulle lenti, ombre laterali sul viso ed espressione neutra.
• Cambio rapido del formato nella schermata risultato, cronologia locale degli originali e regolazione naturale della luminosità.`,
    supportUrl: 'https://doaipm.com', marketingUrl: 'https://doaipm.com',
  },
};

// App / version-level fields.
export const appFields = {
  primaryCategory: 'PHOTO_AND_VIDEO',
  secondaryCategory: 'UTILITIES',
  contentRightsDeclaration: 'DOES_NOT_USE_THIRD_PARTY_CONTENT',
  copyright: '2026 doaipm',
  releaseType: 'AFTER_APPROVAL', // auto-publish once approved
};

// App Review contact (Apple uses it only if they need to reach you during review).
// Kept out of source (public repo) — set ASC_CONTACT_* in your env before a release.
export const reviewContact = {
  contactFirstName: process.env.ASC_CONTACT_FIRST || 'Xiangdong',
  contactLastName:  process.env.ASC_CONTACT_LAST  || 'Li',
  contactPhone:     process.env.ASC_CONTACT_PHONE || '',
  contactEmail:     process.env.ASC_CONTACT_EMAIL || '',
  demoAccountRequired: false,
};

// Age rating → 4+ (everything none/false). Apple's schema requires ALL these keys.
export const ageRating = {
  alcoholTobaccoOrDrugUseOrReferences: 'NONE', contests: 'NONE', gamblingSimulated: 'NONE',
  horrorOrFearThemes: 'NONE', matureOrSuggestiveThemes: 'NONE', medicalOrTreatmentInformation: 'NONE',
  profanityOrCrudeHumor: 'NONE', sexualContentGraphicAndNudity: 'NONE', sexualContentOrNudity: 'NONE',
  violenceCartoonOrFantasy: 'NONE', violenceRealistic: 'NONE', violenceRealisticProlongedGraphicOrSadistic: 'NONE',
  gunsOrOtherWeapons: 'NONE',
  gambling: false, unrestrictedWebAccess: false, advertising: false, lootBox: false,
  userGeneratedContent: false, ageAssurance: false, healthOrWellnessTopics: false,
  messagingAndChat: false, parentalControls: false,
  socialMedia: false, socialMediaAgeRestricted: false,
};

// Screenshots: 6.9" (1290x2796) marketing images per locale, generated by screenshots.swift.
export const screenshots = {
  displayType: 'APP_IPHONE_67',
  dir: new URL('./screenshots/', import.meta.url).pathname,
  locales: {
    'en-US':   ['ss_en_1.png',     'ss_en_2.png',     'ss_en_3.png'],
    'zh-Hans': ['ss_zh_1.png',     'ss_zh_2.png',     'ss_zh_3.png'],
    'zh-Hant': ['ss_zhtw_1.png',   'ss_zhtw_2.png',   'ss_zhtw_3.png'],
    'ja':      ['ss_ja_1.png',     'ss_ja_2.png',     'ss_ja_3.png'],
    'ko':      ['ss_ko_1.png',     'ss_ko_2.png',     'ss_ko_3.png'],
    'fr-FR':   ['ss_fr_1.png',     'ss_fr_2.png',     'ss_fr_3.png'],
    'de-DE':   ['ss_de_1.png',     'ss_de_2.png',     'ss_de_3.png'],
    'it':      ['ss_it_1.png',     'ss_it_2.png',     'ss_it_3.png'],
  },
};
