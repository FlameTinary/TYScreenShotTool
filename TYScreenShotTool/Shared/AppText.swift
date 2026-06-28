//
//  AppText.swift
//  TYScreenShotTool
//
//  Created by Codex on 2026/6/21.
//

import Foundation

enum AppText {
    private static var language: AppLanguage {
        AppLocalization.currentLanguage()
    }

    private static func choose(
        zhHans: String,
        en: String,
        ja: String,
        ko: String,
        de: String,
        fr: String
    ) -> String {
        switch language {
        case .simplifiedChinese:
            return zhHans
        case .english:
            return en
        case .japanese:
            return ja
        case .korean:
            return ko
        case .german:
            return de
        case .french:
            return fr
        case .system:
            return en
        }
    }

    static var annotationRectangle: String { choose(zhHans: "矩形", en: "Rectangle", ja: "長方形", ko: "사각형", de: "Rechteck", fr: "Rectangle") }
    static var annotationEllipse: String { choose(zhHans: "圆形", en: "Ellipse", ja: "楕円", ko: "원형", de: "Ellipse", fr: "Ellipse") }
    static var annotationArrow: String { choose(zhHans: "箭头", en: "Arrow", ja: "矢印", ko: "화살표", de: "Pfeil", fr: "Flèche") }
    static var annotationPen: String { choose(zhHans: "画笔", en: "Pen", ja: "ペン", ko: "펜", de: "Stift", fr: "Stylo") }
    static var annotationMosaic: String { choose(zhHans: "马赛克", en: "Mosaic", ja: "モザイク", ko: "모자이크", de: "Mosaik", fr: "Mosaïque") }
    static var annotationText: String { choose(zhHans: "文字", en: "Text", ja: "テキスト", ko: "텍스트", de: "Text", fr: "Texte") }
    static var annotationLine: String {
        choose(zhHans: "线条", en: "Line", ja: "線", ko: "선", de: "Linie", fr: "Ligne")
    }
    static var penModeSingleColor: String { choose(zhHans: "单一颜色", en: "Single Color", ja: "単色", ko: "단색", de: "Einfarbig", fr: "Couleur unie") }
    static var penModeGaussianBlur: String { choose(zhHans: "高斯模糊", en: "Gaussian Blur", ja: "ガウスぼかし", ko: "가우시안 블러", de: "Gaußsche Unschärfe", fr: "Flou gaussien") }
    static var penModeMosaic: String { choose(zhHans: "马赛克", en: "Mosaic", ja: "モザイク", ko: "모자이크", de: "Mosaik", fr: "Mosaïque") }
    static var mosaicStyleMosaic: String { choose(zhHans: "马赛克", en: "Mosaic", ja: "モザイク", ko: "모자이크", de: "Mosaik", fr: "Mosaïque") }
    static var mosaicStyleGlass: String { choose(zhHans: "毛玻璃", en: "Glass", ja: "すりガラス", ko: "반투명 유리", de: "Milchglas", fr: "Verre dépoli") }
    static var annotationPanelLineWidth: String { choose(zhHans: "大小", en: "Size", ja: "サイズ", ko: "크기", de: "Größe", fr: "Taille") }
    static var annotationPanelOpacity: String { choose(zhHans: "不透明度", en: "Opacity", ja: "不透明度", ko: "불투명도", de: "Deckkraft", fr: "Opacité") }
    static var annotationPanelColor: String { choose(zhHans: "颜色", en: "Color", ja: "色", ko: "색상", de: "Farbe", fr: "Couleur") }
    static var annotationPanelCurvedArrow: String { choose(zhHans: "曲线箭头", en: "Curved Arrow", ja: "曲線矢印", ko: "곡선 화살표", de: "Gebogener Pfeil", fr: "Flèche courbe") }

    static var captureCornerRadius: String { choose(zhHans: "圆角", en: "Corner", ja: "角丸", ko: "둥근 모서리", de: "Ecken", fr: "Coins") }
    static var rectanglePanelLineWidth: String { choose(zhHans: "粗细", en: "Width", ja: "太さ", ko: "두께", de: "Breite", fr: "Épaisseur") }
    static var rectanglePanelOpacity: String { choose(zhHans: "不透明度", en: "Opacity", ja: "不透明度", ko: "불투명도", de: "Deckkraft", fr: "Opacité") }
    static var rectanglePanelCornerRadius: String { choose(zhHans: "圆角", en: "Corner Radius", ja: "角丸", ko: "모서리 반경", de: "Eckenradius", fr: "Rayon") }
    static var rectanglePanelFill: String { choose(zhHans: "填充", en: "Fill", ja: "塗り", ko: "채우기", de: "Füllung", fr: "Remplissage") }
    static var rectanglePanelFilled: String { choose(zhHans: "实心", en: "Filled", ja: "塗りつぶし", ko: "채우기", de: "Gefüllt", fr: "Plein") }
    static var rectanglePanelColor: String { choose(zhHans: "颜色", en: "Color", ja: "色", ko: "색상", de: "Farbe", fr: "Couleur") }
    static var captureShadow: String { choose(zhHans: "阴影", en: "Shadow", ja: "影", ko: "그림자", de: "Schatten", fr: "Ombre") }
    static var captureUndo: String { choose(zhHans: "撤销", en: "Undo", ja: "取り消し", ko: "실행 취소", de: "Rückgängig", fr: "Annuler") }
    static var captureLongCapture: String { choose(zhHans: "长截图", en: "Long Capture", ja: "長いキャプチャ", ko: "긴 캡처", de: "Lange Aufnahme", fr: "Capture longue") }

    static var scrollingCapturePreviewPreparingTitle: String {
        choose(
            zhHans: "等待生成预览",
            en: "Preparing Preview",
            ja: "プレビューを準備中",
            ko: "미리보기를 준비 중",
            de: "Vorschau wird vorbereitet",
            fr: "Préparation de l’aperçu"
        )
    }

    static var scrollingCapturePreviewPreparingMessage: String {
        choose(
            zhHans: "开始滚动后，这里会持续更新长截图预览。",
            en: "The long-capture preview will update here after scrolling starts.",
            ja: "スクロールを開始すると、ここに長いキャプチャのプレビューが更新されます。",
            ko: "스크롤을 시작하면 여기에서 긴 캡처 미리보기가 계속 업데이트됩니다.",
            de: "Sobald du scrollst, wird hier die Vorschau der langen Aufnahme laufend aktualisiert.",
            fr: "Dès que le défilement commence, l’aperçu de la capture longue se met à jour ici."
        )
    }

    static var capturePin: String { choose(zhHans: "图钉", en: "Pin", ja: "ピン留め", ko: "고정", de: "Anheften", fr: "Épingler") }
    static var captureCopy: String { choose(zhHans: "复制", en: "Copy", ja: "コピー", ko: "복사", de: "Kopieren", fr: "Copier") }
    static var captureSave: String { choose(zhHans: "保存", en: "Save", ja: "保存", ko: "저장", de: "Speichern", fr: "Enregistrer") }
    static var captureCancel: String { choose(zhHans: "取消", en: "Cancel", ja: "キャンセル", ko: "취소", de: "Abbrechen", fr: "Annuler") }
    static var captureOCR: String { choose(zhHans: "OCR", en: "OCR", ja: "OCR", ko: "OCR", de: "OCR", fr: "OCR") }
    static var captureTranslate: String { choose(zhHans: "翻译", en: "Translate", ja: "翻訳", ko: "번역", de: "Übersetzen", fr: "Traduire") }
    static var captureAI: String { choose(zhHans: "AI", en: "AI", ja: "AI", ko: "AI", de: "KI", fr: "IA") }
    static var captureTextInputPlaceholder: String { choose(zhHans: "输入文字", en: "Enter text", ja: "文字を入力", ko: "텍스트 입력", de: "Text eingeben", fr: "Saisir du texte") }

    static var ocrWindowTitle: String { choose(zhHans: "OCR 结果", en: "OCR Result", ja: "OCR 結果", ko: "OCR 결과", de: "OCR-Ergebnis", fr: "Résultat OCR") }
    static var ocrEmpty: String { choose(zhHans: "未识别到文字", en: "No text recognized", ja: "文字を認識できませんでした", ko: "인식된 문자가 없습니다", de: "Kein Text erkannt", fr: "Aucun texte reconnu") }
    static var ocrErrorNoText: String { choose(zhHans: "截图中未识别到文字。", en: "No text was recognized from the screenshot.", ja: "スクリーンショットから文字を認識できませんでした。", ko: "스크린샷에서 문자를 인식하지 못했습니다.", de: "Im Screenshot wurde kein Text erkannt.", fr: "Aucun texte n’a été reconnu dans la capture.") }
    static var ocrErrorEmptyText: String { choose(zhHans: "识别结果为空。", en: "Recognized text is empty.", ja: "認識結果が空です。", ko: "인식 결과가 비어 있습니다.", de: "Der erkannte Text ist leer.", fr: "Le texte reconnu est vide.") }
    static var ocrErrorRequestFailedPrefix: String { choose(zhHans: "OCR 请求失败", en: "OCR request failed", ja: "OCR リクエストに失敗しました", ko: "OCR 요청에 실패했습니다", de: "OCR-Anfrage fehlgeschlagen", fr: "La requête OCR a échoué") }
    static var ocrFailedToast: String { choose(zhHans: "OCR 识别失败", en: "OCR failed", ja: "OCR に失敗しました", ko: "OCR 실패", de: "OCR fehlgeschlagen", fr: "Échec de l’OCR") }
    static var ocrCopiedToast: String { choose(zhHans: "OCR 已复制到剪贴板", en: "OCR copied to clipboard", ja: "OCR をクリップボードにコピーしました", ko: "OCR을 클립보드에 복사했습니다", de: "OCR in die Zwischenablage kopiert", fr: "OCR copié dans le presse-papiers") }
    static var ocrCopyFailedToast: String { choose(zhHans: "OCR 复制失败", en: "Failed to copy OCR text", ja: "OCR のコピーに失敗しました", ko: "OCR 복사 실패", de: "OCR konnte nicht kopiert werden", fr: "Échec de la copie OCR") }

    static var aiTranslationMenu: String { choose(zhHans: "翻译语言", en: "Translation", ja: "翻訳", ko: "번역", de: "Übersetzung", fr: "Traduction") }
    static var aiModeDeveloperError: String { choose(zhHans: "开发报错分析", en: "Developer Error Analysis", ja: "開発エラー分析", ko: "개발 오류 분석", de: "Entwicklerfehler analysieren", fr: "Analyse d’erreur de développement") }
    static var aiModeSummary: String { choose(zhHans: "摘要总结", en: "Summary", ja: "要約", ko: "요약", de: "Zusammenfassung", fr: "Résumé") }
    static var aiModeInterfaceStructure: String { choose(zhHans: "界面结构识别", en: "Interface Structure", ja: "画面構造認識", ko: "UI 구조 분석", de: "Oberflächenstruktur", fr: "Structure d’interface") }
    static var aiModeTranslationChinese: String { choose(zhHans: "翻译成中文", en: "Translate to Chinese", ja: "中国語に翻訳", ko: "중국어로 번역", de: "Ins Chinesische übersetzen", fr: "Traduire en chinois") }
    static var aiModeTranslationEnglish: String { choose(zhHans: "翻译成英文", en: "Translate to English", ja: "英語に翻訳", ko: "영어로 번역", de: "Ins Englische übersetzen", fr: "Traduire en anglais") }

    static var aiLoadingDeveloperError: String { choose(zhHans: "AI 正在分析...", en: "AI is analyzing...", ja: "AI が分析中です...", ko: "AI가 분석 중입니다...", de: "KI analysiert...", fr: "L’IA analyse...") }
    static var aiLoadingSummary: String { choose(zhHans: "AI 正在总结...", en: "AI is summarizing...", ja: "AI が要約中です...", ko: "AI가 요약 중입니다...", de: "KI fasst zusammen...", fr: "L’IA résume...") }
    static var aiLoadingInterfaceStructure: String { choose(zhHans: "AI 正在识别界面结构...", en: "AI is identifying the interface structure...", ja: "AI が画面構造を認識中です...", ko: "AI가 UI 구조를 분석 중입니다...", de: "KI erkennt die Oberflächenstruktur...", fr: "L’IA identifie la structure de l’interface...") }
    static var aiLoadingTranslationChinese: String { choose(zhHans: "AI 正在翻译成中文...", en: "AI is translating to Chinese...", ja: "AI が中国語に翻訳中です...", ko: "AI가 중국어로 번역 중입니다...", de: "KI übersetzt ins Chinesische...", fr: "L’IA traduit en chinois...") }
    static var aiLoadingTranslationEnglish: String { choose(zhHans: "AI 正在翻译成英文...", en: "AI is translating to English...", ja: "AI が英語に翻訳中です...", ko: "AI가 영어로 번역 중입니다...", de: "KI übersetzt ins Englische...", fr: "L’IA traduit en anglais...") }

    static var aiResultTitle: String { choose(zhHans: "AI 分析", en: "AI Analysis", ja: "AI 分析", ko: "AI 분석", de: "KI-Analyse", fr: "Analyse IA") }
    static var aiResultSummaryTitle: String { choose(zhHans: "摘要总结", en: "Summary", ja: "要約", ko: "요약", de: "Zusammenfassung", fr: "Résumé") }
    static var aiResultInterfaceStructureTitle: String { choose(zhHans: "界面结构识别", en: "Interface Structure", ja: "画面構造認識", ko: "UI 구조 분석", de: "Oberflächenstruktur", fr: "Structure d’interface") }
    static var aiResultCopyAll: String { choose(zhHans: "复制全部", en: "Copy All", ja: "すべてコピー", ko: "전체 복사", de: "Alles kopieren", fr: "Tout copier") }
    static var aiResultCopySuggestion: String { choose(zhHans: "复制建议", en: "Copy Suggestions", ja: "提案をコピー", ko: "제안 복사", de: "Vorschläge kopieren", fr: "Copier les suggestions") }
    static var aiResultCopySummary: String { choose(zhHans: "复制重点", en: "Copy Highlights", ja: "要点をコピー", ko: "핵심 복사", de: "Kernaussagen kopieren", fr: "Copier les points clés") }
    static var aiResultCopyStructure: String { choose(zhHans: "复制结构", en: "Copy Structure", ja: "構造をコピー", ko: "구조 복사", de: "Struktur kopieren", fr: "Copier la structure") }
    static var aiResultCopyTranslation: String { choose(zhHans: "复制译文", en: "Copy Translation", ja: "訳文をコピー", ko: "번역문 복사", de: "Übersetzung kopieren", fr: "Copier la traduction") }
    static var aiResultRetry: String { choose(zhHans: "重试", en: "Retry", ja: "再試行", ko: "다시 시도", de: "Erneut versuchen", fr: "Réessayer") }
    static var aiResultClose: String { choose(zhHans: "关闭", en: "Close", ja: "閉じる", ko: "닫기", de: "Schließen", fr: "Fermer") }
    static var aiResultError: String { choose(zhHans: "AI 分析失败", en: "AI Analysis Failed", ja: "AI 分析に失敗しました", ko: "AI 분석 실패", de: "KI-Analyse fehlgeschlagen", fr: "Échec de l’analyse IA") }
    static var aiResultCopiedSuggestion: String { choose(zhHans: "建议下一步已复制", en: "Suggestions copied", ja: "次の提案をコピーしました", ko: "다음 단계 제안을 복사했습니다", de: "Vorschläge kopiert", fr: "Suggestions copiées") }
    static var aiResultCopiedSummary: String { choose(zhHans: "摘要重点已复制", en: "Highlights copied", ja: "要点をコピーしました", ko: "핵심 내용을 복사했습니다", de: "Kernaussagen kopiert", fr: "Points clés copiés") }
    static var aiResultCopiedStructure: String { choose(zhHans: "界面结构已复制", en: "Structure copied", ja: "構造をコピーしました", ko: "구조를 복사했습니다", de: "Struktur kopiert", fr: "Structure copiée") }
    static var aiResultCopiedTranslation: String { choose(zhHans: "译文已复制", en: "Translation copied", ja: "訳文をコピーしました", ko: "번역문을 복사했습니다", de: "Übersetzung kopiert", fr: "Traduction copiée") }
    static var aiFailedToast: String { choose(zhHans: "AI 分析失败", en: "AI analysis failed", ja: "AI 分析に失敗しました", ko: "AI 분석 실패", de: "KI-Analyse fehlgeschlagen", fr: "Échec de l’analyse IA") }
    static var aiVisionFailedToast: String { choose(zhHans: "AI 识别失败", en: "AI text extraction failed", ja: "AI 文字認識に失敗しました", ko: "AI 문자 추출 실패", de: "KI-Texterkennung fehlgeschlagen", fr: "Échec de l’extraction IA") }
    static var aiInProgressToast: String { choose(zhHans: "AI 正在分析中", en: "AI is already analyzing", ja: "AI が分析中です", ko: "AI가 이미 분석 중입니다", de: "Die KI analysiert bereits", fr: "L’IA analyse déjà") }
    static var aiCopiedToast: String { choose(zhHans: "AI 分析结果已复制", en: "AI result copied", ja: "AI の結果をコピーしました", ko: "AI 결과를 복사했습니다", de: "KI-Ergebnis kopiert", fr: "Résultat IA copié") }
    static var aiCopyFailedToast: String { choose(zhHans: "AI 结果复制失败", en: "Failed to copy AI result", ja: "AI 結果のコピーに失敗しました", ko: "AI 결과 복사 실패", de: "KI-Ergebnis konnte nicht kopiert werden", fr: "Échec de la copie du résultat IA") }
    static var aiNoValidText: String { choose(zhHans: "AI 未识别到有效文字", en: "AI did not find valid text", ja: "AI が有効な文字を認識できませんでした", ko: "AI가 유효한 문자를 찾지 못했습니다", de: "Die KI hat keinen gültigen Text erkannt", fr: "L’IA n’a détecté aucun texte exploitable") }
    static var aiNoValidContent: String { choose(zhHans: "AI 未识别到有效内容", en: "AI did not find valid content", ja: "AI が有効な内容を認識できませんでした", ko: "AI가 유효한 내용을 찾지 못했습니다", de: "Die KI hat keinen gültigen Inhalt erkannt", fr: "L’IA n’a détecté aucun contenu exploitable") }
    static var aiMissingAPIKey: String { choose(zhHans: "OpenAI API Key 未配置。", en: "OpenAI API key is not configured.", ja: "OpenAI API キーが設定されていません。", ko: "OpenAI API 키가 설정되지 않았습니다.", de: "Der OpenAI-API-Schlüssel ist nicht konfiguriert.", fr: "La clé API OpenAI n’est pas configurée.") }
    static var aiEmptyInput: String { choose(zhHans: "OCR 文本为空。", en: "The OCR text is empty.", ja: "OCR テキストが空です。", ko: "OCR 텍스트가 비어 있습니다.", de: "Der OCR-Text ist leer.", fr: "Le texte OCR est vide.") }
    static var aiInvalidResponse: String { choose(zhHans: "AI 返回格式无效。", en: "The AI response format is invalid.", ja: "AI の応答形式が無効です。", ko: "AI 응답 형식이 올바르지 않습니다.", de: "Das Antwortformat der KI ist ungültig.", fr: "Le format de réponse de l’IA est invalide.") }
    static var aiEmptyOutput: String { choose(zhHans: "AI 返回内容为空。", en: "The AI response is empty.", ja: "AI の応答内容が空です。", ko: "AI 응답 내용이 비어 있습니다.", de: "Die KI-Antwort ist leer.", fr: "La réponse de l’IA est vide.") }
    static var aiLowQualityOutput: String { choose(zhHans: "AI 返回结果不完整，请重试或调整截图范围后再试。", en: "The AI result is incomplete. Try again or adjust the capture area.", ja: "AI の結果が不完全です。再試行するか、キャプチャ範囲を調整してください。", ko: "AI 결과가 불완전합니다. 다시 시도하거나 캡처 범위를 조정해 주세요.", de: "Das KI-Ergebnis ist unvollständig. Versuche es erneut oder passe den Aufnahmebereich an.", fr: "Le résultat IA est incomplet. Réessayez ou ajustez la zone de capture.") }
    static var aiRequestFailedPrefix: String { choose(zhHans: "AI 请求失败", en: "AI request failed", ja: "AI リクエストに失敗しました", ko: "AI 요청에 실패했습니다", de: "KI-Anfrage fehlgeschlagen", fr: "La requête IA a échoué") }
    static var aiBaseURLInvalid: String { choose(zhHans: "AI Base URL 无效。", en: "The AI base URL is invalid.", ja: "AI Base URL が無効です。", ko: "AI Base URL이 올바르지 않습니다.", de: "Die AI-Base-URL ist ungültig.", fr: "L’URL de base de l’IA est invalide.") }
    static var aiRegionPolicyBlocked: String { choose(zhHans: "当前区域不可使用商业 AI。", en: "Commercial AI is not available in the current region.", ja: "現在の地域では商用 AI を利用できません。", ko: "현재 지역에서는 상업용 AI를 사용할 수 없습니다.", de: "Kommerzielle KI ist in der aktuellen Region nicht verfügbar.", fr: "L’IA commerciale n’est pas disponible dans la région actuelle.") }
    static var aiProPromptTitle: String { choose(zhHans: "AI Pro 即将开放", en: "AI Pro is coming soon", ja: "AI Pro は近日公開予定です", ko: "AI Pro가 곧 제공됩니다", de: "AI Pro kommt bald", fr: "AI Pro arrive bientôt") }
    static var aiProPromptMessage: String { choose(zhHans: "海外区 AI Pro 将通过 Sign in with Apple 与订阅开通。本阶段仅展示入口说明，不会上传截图，也不会调用 AI 后端。", en: "AI Pro for overseas regions will use Sign in with Apple and subscriptions. This stage only shows the entry shell, and will not upload screenshots or call the AI backend.", ja: "海外向け AI Pro は Sign in with Apple とサブスクリプションで提供予定です。この段階では入口の説明のみを表示し、スクリーンショットのアップロードや AI バックエンド呼び出しは行いません。", ko: "해외 지역의 AI Pro는 Sign in with Apple과 구독으로 제공될 예정입니다. 이 단계에서는 진입 안내만 표시하며 스크린샷 업로드나 AI 백엔드 호출은 하지 않습니다.", de: "AI Pro fuer Regionen ausserhalb Chinas wird Sign in with Apple und Abonnements verwenden. In dieser Phase wird nur die Einstiegshuelse angezeigt; Screenshots werden nicht hochgeladen und das KI-Backend wird nicht aufgerufen.", fr: "AI Pro pour les régions hors Chine utilisera Sign in with Apple et les abonnements. Cette étape affiche seulement l’entrée, sans téléverser de capture ni appeler le backend IA.") }
    static var aiProPromptPrimaryButton: String { choose(zhHans: "知道了", en: "OK", ja: "OK", ko: "확인", de: "OK", fr: "OK") }
    static var aiProSubscribeButton: String { choose(zhHans: "订阅", en: "Subscribe", ja: "登録", ko: "구독", de: "Abonnieren", fr: "S’abonner") }
    static var aiProRestoreButton: String { choose(zhHans: "恢复购买", en: "Restore Purchases", ja: "購入を復元", ko: "구매 복원", de: "Käufe wiederherstellen", fr: "Restaurer les achats") }
    static var aiProNotNowButton: String { choose(zhHans: "稍后", en: "Not Now", ja: "あとで", ko: "나중에", de: "Nicht jetzt", fr: "Plus tard") }
    static var aiProSubscriptionLoadingMessage: String { choose(zhHans: "正在加载 AI Pro Monthly 订阅商品...", en: "Loading the AI Pro Monthly subscription...", ja: "AI Pro Monthly サブスクリプションを読み込み中...", ko: "AI Pro Monthly 구독을 불러오는 중...", de: "AI Pro Monthly-Abonnement wird geladen...", fr: "Chargement de l’abonnement AI Pro Monthly...") }
    static var aiProSubscriptionUnavailableMessage: String { choose(zhHans: "AI Pro Monthly 当前不可用。请确认 StoreKit 配置、Sandbox 账号或 App Store Connect 商品状态后重试。", en: "AI Pro Monthly is not available. Check the StoreKit configuration, Sandbox account, or App Store Connect product status and try again.", ja: "AI Pro Monthly は現在利用できません。StoreKit 設定、Sandbox アカウント、App Store Connect の商品状態を確認して再試行してください。", ko: "AI Pro Monthly를 현재 사용할 수 없습니다. StoreKit 구성, Sandbox 계정 또는 App Store Connect 상품 상태를 확인한 뒤 다시 시도하세요.", de: "AI Pro Monthly ist nicht verfügbar. Prüfe StoreKit-Konfiguration, Sandbox-Konto oder Produktstatus in App Store Connect und versuche es erneut.", fr: "AI Pro Monthly n’est pas disponible. Vérifiez la configuration StoreKit, le compte Sandbox ou l’état du produit App Store Connect, puis réessayez.") }
    static func aiProSubscriptionOfferMessage(_ price: String) -> String { choose(zhHans: "订阅 AI Pro Monthly 后，后续版本将可使用截图 AI 分析能力。\n\n价格：\(price)\n\n本阶段只接入 StoreKit 购买与恢复入口；AI 请求仍需后端在后续 Feature 中校验登录、订阅、地区和额度。", en: "Subscribe to AI Pro Monthly to unlock screenshot AI analysis in a later version.\n\nPrice: \(price)\n\nThis stage only connects StoreKit purchase and restore entry points. AI requests still require backend validation for login, subscription, region, and quota in later features.", ja: "AI Pro Monthly に登録すると、今後のバージョンでスクリーンショット AI 分析を利用できる予定です。\n\n価格: \(price)\n\nこの段階では StoreKit の購入と復元入口のみを接続します。AI リクエストは後続 Feature でログイン、サブスクリプション、地域、利用枠をバックエンド検証します。", ko: "AI Pro Monthly를 구독하면 이후 버전에서 스크린샷 AI 분석을 사용할 수 있습니다.\n\n가격: \(price)\n\n이 단계에서는 StoreKit 구매 및 복원 진입점만 연결합니다. AI 요청은 이후 Feature에서 로그인, 구독, 지역, 사용량을 백엔드에서 검증해야 합니다.", de: "Mit AI Pro Monthly wird Screenshot-KI-Analyse in einer späteren Version freigeschaltet.\n\nPreis: \(price)\n\nDiese Phase verbindet nur StoreKit-Kauf und Wiederherstellung. KI-Anfragen benötigen in späteren Features weiterhin Backend-Prüfung für Login, Abo, Region und Kontingent.", fr: "Abonnez-vous à AI Pro Monthly pour débloquer l’analyse IA des captures dans une version ultérieure.\n\nPrix : \(price)\n\nCette étape connecte seulement les entrées d’achat et de restauration StoreKit. Les requêtes IA devront encore être validées côté backend pour la connexion, l’abonnement, la région et le quota dans les prochaines features.") }
    static var aiProSubscribedTitle: String { choose(zhHans: "AI Pro 已订阅", en: "AI Pro Subscribed", ja: "AI Pro 登録済み", ko: "AI Pro 구독 중", de: "AI Pro abonniert", fr: "AI Pro abonné") }
    static var aiProSubscribedMessage: String { choose(zhHans: "本机已检测到有效 AI Pro Monthly 订阅。后续仍会接入后端校验后再开放 AI 请求。", en: "A valid AI Pro Monthly subscription was detected locally. AI requests will still wait for backend validation in a later feature.", ja: "有効な AI Pro Monthly サブスクリプションをローカルで検出しました。AI リクエストは後続 Feature のバックエンド検証後に開放します。", ko: "로컬에서 유효한 AI Pro Monthly 구독을 감지했습니다. AI 요청은 이후 Feature의 백엔드 검증 후에만 열립니다.", de: "Ein gültiges AI Pro Monthly-Abonnement wurde lokal erkannt. KI-Anfragen werden erst nach Backend-Prüfung in einem späteren Feature freigeschaltet.", fr: "Un abonnement AI Pro Monthly valide a été détecté localement. Les requêtes IA attendront encore la validation backend dans une prochaine feature.") }
    static func aiProSubscriptionFailedMessage(_ message: String) -> String { choose(zhHans: "AI Pro 订阅操作失败：\(message)", en: "AI Pro subscription failed: \(message)", ja: "AI Pro サブスクリプション操作に失敗しました: \(message)", ko: "AI Pro 구독 작업 실패: \(message)", de: "AI Pro-Abonnement fehlgeschlagen: \(message)", fr: "Échec de l’abonnement AI Pro : \(message)") }
    static var aiProTransactionUnverified: String { choose(zhHans: "StoreKit 交易未通过本地验证。", en: "The StoreKit transaction could not be verified locally.", ja: "StoreKit 取引をローカルで検証できませんでした。", ko: "StoreKit 거래를 로컬에서 검증할 수 없습니다.", de: "Die StoreKit-Transaktion konnte lokal nicht verifiziert werden.", fr: "La transaction StoreKit n’a pas pu être vérifiée localement.") }
    static var aiProTransactionPending: String { choose(zhHans: "StoreKit 交易仍在等待处理。", en: "The StoreKit transaction is still pending.", ja: "StoreKit 取引はまだ保留中です。", ko: "StoreKit 거래가 아직 대기 중입니다.", de: "Die StoreKit-Transaktion ist noch ausstehend.", fr: "La transaction StoreKit est toujours en attente.") }
    static var aiProTransactionUnknown: String { choose(zhHans: "StoreKit 返回了未知交易状态。", en: "StoreKit returned an unknown transaction state.", ja: "StoreKit が不明な取引状態を返しました。", ko: "StoreKit이 알 수 없는 거래 상태를 반환했습니다.", de: "StoreKit hat einen unbekannten Transaktionsstatus zurückgegeben.", fr: "StoreKit a renvoyé un état de transaction inconnu.") }
    static var aiUnknownServerError: String { choose(zhHans: "未知服务端错误。", en: "Unknown server error.", ja: "不明なサーバーエラーです。", ko: "알 수 없는 서버 오류입니다.", de: "Unbekannter Serverfehler.", fr: "Erreur serveur inconnue.") }
    static var aiResponseDecodeFailedPrefix: String { choose(zhHans: "响应解析失败", en: "Failed to decode response", ja: "レスポンスの解析に失敗しました", ko: "응답 해석에 실패했습니다", de: "Antwort konnte nicht dekodiert werden", fr: "Échec du décodage de la réponse") }
    static var aiImageMissingAPIKey: String { choose(zhHans: "OpenAI API Key 未配置。", en: "OpenAI API key is not configured.", ja: "OpenAI API キーが設定されていません。", ko: "OpenAI API 키가 설정되지 않았습니다.", de: "Der OpenAI-API-Schlüssel ist nicht konfiguriert.", fr: "La clé API OpenAI n’est pas configurée.") }
    static var aiImageEncodingFailed: String { choose(zhHans: "截图编码失败。", en: "Failed to encode the screenshot.", ja: "スクリーンショットのエンコードに失敗しました。", ko: "스크린샷 인코딩에 실패했습니다.", de: "Der Screenshot konnte nicht kodiert werden.", fr: "Échec de l’encodage de la capture.") }
    static var aiImageInvalidResponse: String { choose(zhHans: "AI 识别返回格式无效。", en: "The AI extraction response format is invalid.", ja: "AI 抽出の応答形式が無効です。", ko: "AI 추출 응답 형식이 올바르지 않습니다.", de: "Das Antwortformat der KI-Erkennung ist ungültig.", fr: "Le format de réponse de l’extraction IA est invalide.") }
    static var aiImageEmptyOutput: String { choose(zhHans: "AI 识别返回内容为空。", en: "The AI extraction response is empty.", ja: "AI 抽出の応答内容が空です。", ko: "AI 추출 응답 내용이 비어 있습니다.", de: "Die Antwort der KI-Erkennung ist leer.", fr: "La réponse de l’extraction IA est vide.") }
    static var aiImageRequestFailedPrefix: String { choose(zhHans: "AI 识别请求失败", en: "AI extraction request failed", ja: "AI 抽出リクエストに失敗しました", ko: "AI 추출 요청에 실패했습니다", de: "KI-Erkennungsanfrage fehlgeschlagen", fr: "La requête d’extraction IA a échoué") }
    static var aiVisionExtractionInstructions: String { choose(zhHans: "你负责从截图图片中提取文字。", en: "You extract text from screenshots.", ja: "スクリーンショット画像から文字を抽出してください。", ko: "스크린샷 이미지에서 문자를 추출하세요.", de: "Du extrahierst Text aus Screenshots.", fr: "Tu extrais le texte des captures d’écran.") }
    static var aiVisionExtractionPrompt: String { choose(zhHans: "你负责从截图中尽量忠实提取可见文字。\n要求：\n- 只输出截图中的文字内容\n- 不要解释、不要总结、不要补充前言\n- 不要输出 Markdown 代码块\n- 保持关键信息原始顺序\n- 如果没有可识别的有效文字，返回空字符串", en: "Extract the visible text from the screenshot as faithfully as possible.\nRequirements:\n- Output only the text from the screenshot\n- Do not explain, summarize, or add any introduction\n- Do not output Markdown code blocks\n- Preserve the original order of key information\n- Return an empty string if there is no recognizable useful text", ja: "スクリーンショット内の見える文字をできるだけ忠実に抽出してください。\n要件:\n- スクリーンショット内の文字だけを出力する\n- 説明、要約、前置きは加えない\n- Markdown のコードブロックを出力しない\n- 重要な情報の元の順序を保つ\n- 有効な文字が認識できない場合は空文字を返す", ko: "스크린샷에 보이는 문자를 가능한 한 정확하게 추출하세요.\n요구 사항:\n- 스크린샷의 문자만 출력합니다\n- 설명, 요약, 서두를 추가하지 않습니다\n- Markdown 코드 블록을 출력하지 않습니다\n- 핵심 정보의 원래 순서를 유지합니다\n- 인식 가능한 유효 문자가 없으면 빈 문자열을 반환합니다", de: "Extrahiere den sichtbaren Text aus dem Screenshot so originalgetreu wie möglich.\nAnforderungen:\n- Gib nur den Text aus dem Screenshot aus\n- Erkläre nicht, fasse nicht zusammen und füge keine Einleitung hinzu\n- Gib keine Markdown-Codeblöcke aus\n- Behalte die ursprüngliche Reihenfolge wichtiger Informationen bei\n- Gib einen leeren String zurück, wenn kein brauchbarer Text erkennbar ist", fr: "Extrait le texte visible de la capture aussi fidèlement que possible.\nExigences :\n- N’affiche que le texte présent dans la capture\n- N’explique pas, ne résume pas et n’ajoute pas d’introduction\n- N’affiche pas de blocs de code Markdown\n- Conserve l’ordre d’origine des informations importantes\n- Renvoie une chaîne vide s’il n’y a aucun texte utile reconnaissable") }

    static var developerErrorSummaryTitle: String { choose(zhHans: "报错大意", en: "Error Summary", ja: "エラー概要", ko: "오류 요약", de: "Fehlerübersicht", fr: "Résumé de l’erreur") }
    static var developerErrorCausesTitle: String { choose(zhHans: "可能原因", en: "Possible Causes", ja: "考えられる原因", ko: "가능한 원인", de: "Mögliche Ursachen", fr: "Causes possibles") }
    static var developerErrorNextStepsTitle: String { choose(zhHans: "建议下一步", en: "Suggested Next Steps", ja: "次の推奨手順", ko: "다음 권장 단계", de: "Empfohlene nächste Schritte", fr: "Étapes suivantes suggérées") }
    static var summaryPoint1Title: String { choose(zhHans: "重点 1", en: "Point 1", ja: "要点 1", ko: "핵심 1", de: "Punkt 1", fr: "Point 1") }
    static var summaryPoint2Title: String { choose(zhHans: "重点 2", en: "Point 2", ja: "要点 2", ko: "핵심 2", de: "Punkt 2", fr: "Point 2") }
    static var summaryPoint3Title: String { choose(zhHans: "重点 3", en: "Point 3", ja: "要点 3", ko: "핵심 3", de: "Punkt 3", fr: "Point 3") }
    static var translationSectionTitle: String { choose(zhHans: "译文", en: "Translation", ja: "翻訳", ko: "번역", de: "Übersetzung", fr: "Traduction") }
    static var interfaceStructureTitle: String { choose(zhHans: "界面结构", en: "Interface Structure", ja: "画面構造", ko: "UI 구조", de: "Oberflächenstruktur", fr: "Structure d’interface") }
    static var interfaceComponentsTitle: String { choose(zhHans: "组件识别", en: "Components", ja: "コンポーネント", ko: "구성 요소", de: "Komponenten", fr: "Composants") }
    static var interfaceHierarchyTitle: String { choose(zhHans: "结构层级", en: "Hierarchy", ja: "階層構造", ko: "구조 계층", de: "Hierarchie", fr: "Hiérarchie") }
    static var interfaceVisualTitle: String { choose(zhHans: "视觉特征", en: "Visual Traits", ja: "視覚的特徴", ko: "시각적 특징", de: "Visuelle Merkmale", fr: "Caractéristiques visuelles") }
    static var interfaceInteractionTitle: String { choose(zhHans: "交互语义", en: "Interaction Semantics", ja: "操作の意味", ko: "상호작용 의미", de: "Interaktionssemantik", fr: "Sémantique d’interaction") }
    static var interfaceImplementationTitle: String { choose(zhHans: "实现提示", en: "Implementation Notes", ja: "実装ヒント", ko: "구현 힌트", de: "Implementierungshinweise", fr: "Conseils d’implémentation") }

    static var screenshotCopiedToast: String { choose(zhHans: "已复制截图到剪贴板", en: "Screenshot copied to clipboard", ja: "スクリーンショットをクリップボードにコピーしました", ko: "스크린샷을 클립보드에 복사했습니다", de: "Screenshot in die Zwischenablage kopiert", fr: "Capture copiée dans le presse-papiers") }
    static var screenshotSavedToast: String { choose(zhHans: "截图已保存", en: "Screenshot saved", ja: "スクリーンショットを保存しました", ko: "스크린샷을 저장했습니다", de: "Screenshot gespeichert", fr: "Capture enregistrée") }
    static var scrollingCaptureAnnotationBlocked: String { choose(zhHans: "长截图暂不支持标注后进入", en: "Long capture cannot start after adding annotations", ja: "注釈追加後は長いキャプチャを開始できません", ko: "주석 추가 후에는 긴 캡처를 시작할 수 없습니다", de: "Lange Aufnahme kann nach Anmerkungen nicht gestartet werden", fr: "La capture longue ne peut pas démarrer après ajout d’annotations") }
    static var longScreenshotCopiedToast: String { choose(zhHans: "已复制长截图到剪贴板", en: "Long capture copied to clipboard", ja: "長いキャプチャをクリップボードにコピーしました", ko: "긴 캡처를 클립보드에 복사했습니다", de: "Lange Aufnahme in die Zwischenablage kopiert", fr: "Capture longue copiée dans le presse-papiers") }
    static var longScreenshotSavedToast: String { choose(zhHans: "长截图已保存", en: "Long capture saved", ja: "長いキャプチャを保存しました", ko: "긴 캡처를 저장했습니다", de: "Lange Aufnahme gespeichert", fr: "Capture longue enregistrée") }
    static var longScreenshotFailedToast: String { choose(zhHans: "长截图失败，请调整滚动步进后重试", en: "Long capture failed. Adjust the scroll step and try again.", ja: "長いキャプチャに失敗しました。スクロール間隔を調整して再試行してください。", ko: "긴 캡처에 실패했습니다. 스크롤 간격을 조정한 뒤 다시 시도해 주세요.", de: "Lange Aufnahme fehlgeschlagen. Passe den Scrollschritt an und versuche es erneut.", fr: "La capture longue a échoué. Ajustez le pas de défilement puis réessayez.") }

    static var openSettingsButton: String { choose(zhHans: "打开设置", en: "Open Settings", ja: "設定を開く", ko: "설정 열기", de: "Einstellungen öffnen", fr: "Ouvrir les réglages") }
    static var appQuit: String { choose(zhHans: "退出", en: "Quit", ja: "終了", ko: "종료", de: "Beenden", fr: "Quitter") }
    static var cancelButton: String { choose(zhHans: "取消", en: "Cancel", ja: "キャンセル", ko: "취소", de: "Abbrechen", fr: "Annuler") }
    static var saveDirNotConfiguredTitle: String { choose(zhHans: "未配置保存目录", en: "Save folder not configured", ja: "保存先フォルダが未設定です", ko: "저장 폴더가 설정되지 않았습니다", de: "Kein Speicherordner konfiguriert", fr: "Dossier d’enregistrement non configuré") }
    static var saveDirNotConfiguredMessage: String { choose(zhHans: "请前往 Settings 选择截图 PNG 的保存目录，然后再执行保存。", en: "Open Settings and choose a folder for screenshot PNG files before saving.", ja: "保存する前に、設定でスクリーンショット PNG の保存先フォルダを選択してください。", ko: "저장하기 전에 설정에서 스크린샷 PNG 저장 폴더를 선택해 주세요.", de: "Öffne die Einstellungen und wähle vor dem Speichern einen Ordner für Screenshot-PNG-Dateien.", fr: "Ouvrez les réglages et choisissez un dossier pour les PNG avant d’enregistrer.") }
    static var saveDirAuthExpiredTitle: String { choose(zhHans: "保存目录授权已失效", en: "Save folder permission expired", ja: "保存先フォルダの権限が失効しました", ko: "저장 폴더 권한이 만료되었습니다", de: "Berechtigung für Speicherordner abgelaufen", fr: "Autorisation du dossier expirée") }
    static var saveDirAuthExpiredMessage: String { choose(zhHans: "当前保存目录无法访问，请前往 Settings 重新选择保存目录。", en: "The current save folder is no longer accessible. Re-select it in Settings.", ja: "現在の保存先フォルダにアクセスできません。設定で再選択してください。", ko: "현재 저장 폴더에 접근할 수 없습니다. 설정에서 다시 선택해 주세요.", de: "Auf den aktuellen Speicherordner kann nicht mehr zugegriffen werden. Bitte wähle ihn in den Einstellungen erneut aus.", fr: "Le dossier actuel n’est plus accessible. Veuillez le sélectionner à nouveau dans les réglages.") }
    static var saveDirUnavailableTitle: String { choose(zhHans: "保存目录不可用", en: "Save folder unavailable", ja: "保存先フォルダを利用できません", ko: "저장 폴더를 사용할 수 없습니다", de: "Speicherordner nicht verfügbar", fr: "Dossier d’enregistrement indisponible") }
    static var saveDirUnavailableMessage: String { choose(zhHans: "当前保存目录无法访问，请前往 Settings 检查或重新选择保存目录。", en: "The current save folder is unavailable. Check it or choose another one in Settings.", ja: "現在の保存先フォルダにアクセスできません。設定で確認または再選択してください。", ko: "현재 저장 폴더를 사용할 수 없습니다. 설정에서 확인하거나 다시 선택해 주세요.", de: "Der aktuelle Speicherordner ist nicht verfügbar. Bitte prüfe ihn oder wähle in den Einstellungen einen anderen aus.", fr: "Le dossier actuel est indisponible. Vérifiez-le ou choisissez-en un autre dans les réglages.") }

    static func promptOutputLanguageName(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        case .german:
            return "Deutsch"
        case .french:
            return "Français"
        case .system:
            return "English"
        }
    }
}
