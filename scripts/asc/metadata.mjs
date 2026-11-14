// All App Store metadata for FreeID Photo, in one editable place.
// release.mjs applies this every run, so a brand-new version inherits it too.
// App Store locale codes: en-US, zh-Hans, zh-Hant, ja, ko, fr-FR, de-DE, it.

// App-level info localizations: name + subtitle + privacy policy URL (per locale).
// Subtitle ≤ 30 chars. No price references (guideline 2.3.7): describe what the
// app does, never that it's free/discounted — that lives only in the description.
export const appInfoLocalizations = {
  'en-US':   { name: 'FreeID Photo', subtitle: 'On-device ID photo maker',     privacyPolicyUrl: 'https://doaipm.com/privacy' },
  'zh-Hans': { name: 'FreeID 证件照 · 护照签证照', subtitle: '本地处理不上传 · 打印排版', privacyPolicyUrl: 'https://doaipm.com/privacy' },
};

// Only the locales we also write DESCRIPTION + KEYWORDS for below belong here. Adding an
// appInfo localization makes App Store Connect spawn an empty *version* localization for that
// locale, and Apple then rejects the whole submission with a bare 409 "This resource cannot be
// reviewed". The app's UI is localized in 8 languages regardless (Localization.swift); these
// are store-listing locales. When store copy for ja/ko/fr-FR/de-DE/it/zh-Hant is written, add
// it to `versionLocalizations` and the name/subtitle here in the same change — never one
// without the other. Previously-drafted subtitles, for whoever picks that up:
//   zh-Hant '本機處理不上傳 · 列印排版' | ja '端末内で作る証明写真' | ko '기기 내 처리 증명사진'
//   fr-FR "Photos d'identité hors ligne" | de-DE 'Passfotos lokal erstellt' | it 'Foto tessera sul dispositivo'

// Version localizations: description, keywords (≤100 chars), promo, support/marketing URL,
// and whatsNew (release notes — required for UPDATES, ignored on the very first version).
// Add the other 6 locales here when you have translated descriptions.
export const versionLocalizations = {
  'en-US': {
    description: `FreeID Photo makes a compliant passport or ID photo on your iPhone in seconds — no watermark, no account, nothing to upload.

• 16 specs across 10 countries/regions (US, China, UK, Schengen, Japan, Korea, India, Singapore, and more) — each matched to the official size and head/eye requirements.
• A head-and-shoulders guide lines you up; tap when you're framed.
• On-device AI crops to the exact spec and, where the destination allows it, replaces the background (white / blue / red).
• Outputs the precise pixel size and DPI for printing or online upload.
• Front or back camera — let someone shoot you with the sharper rear lens.
• Save to Photos or share.

Everything runs on-device. Nothing is uploaded.`,
    keywords: 'passport photo,id photo,visa photo,headshot,background,document,1 inch,2 inch,ID picture,compliant',
    promotionalText: 'Free, on-device passport & ID photos. Nothing uploaded, no watermark, full resolution.',
    whatsNew: `• Custom size & file-size (KB) limits — search specs by keyword or enter exact millimetres and max KB for online portals.
• Back-camera voice coach & auto-shutter — shoot yourself with the sharper rear camera guided by spoken prompts.
• Smarter head-crown detection and natural hair-edge blending when replacing backgrounds.`,
    supportUrl: 'https://doaipm.com', marketingUrl: 'https://doaipm.com',
  },
  'zh-Hans': {
    description: `FreeID Photo 在 iPhone 上几秒做好一张合规的证件照 / 护照照片 —— 无水印、无需注册、无需上传。

• 覆盖 10 个国家/地区共 16 种规格(美国、中国、英国、申根、日本、韩国、印度、新加坡等),每种都对应官方尺寸与头部/眼睛位置要求。
• 头肩取景引导帮你对齐,框好即可拍。
• 全程在设备本地用 AI 裁切到精确规格;在允许修图的证件上可一键换背景(白/蓝/红)。
• 输出精确像素尺寸与 DPI,可冲印或网上上传。
• 前置/后置摄像头自由切换,可让他人用后置帮你拍得更清晰。
• 保存到相册或分享。

全部本地处理,不上传任何数据。`,
    keywords: '证件照,护照照片,签证照片,一寸照,二寸照,合规证件照,换背景,白底,蓝底,红底,身份证照片',
    promotionalText: '证件照本地处理，不上传、无水印、原图分辨率。',
    whatsNew: `• 支持自定义毫米尺寸与文件大小（KB）限制，并可按国家、证件或尺寸快速搜索规格。
• 后置相机新增语音引导与对准自动快门，一个人也能用更清晰的后置镜头自拍。
• 优化发顶识别与换底边缘羽化，发丝过渡更自然、头顶留白更精准。`,
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
  dir: new URL('./screenshots/', import.meta.url).pathname, // ss_<locale>_N.png
  locales: {
    'en-US': ['ss_en_1.png', 'ss_en_2.png', 'ss_en_3.png'],
    'zh-Hans': ['ss_zh_1.png', 'ss_zh_2.png', 'ss_zh_3.png'],
  },
};
