import Foundation

/// User-facing languages. `system` is a preference, not a translation table.
public enum AppLanguage: String, Codable, CaseIterable, Sendable, Identifiable {
    case system
    case english
    case spanish
    case french
    case german
    case italian
    case portugueseBrazil
    case dutch
    case arabic
    case japanese
    case korean
    case chineseSimplified
    case chineseTraditional

    public var id: String { rawValue }

    /// Conventional UI order (not the request list).
    public static let displayOrder: [AppLanguage] = [
        .english, .spanish, .french, .german, .italian, .portugueseBrazil,
        .dutch, .arabic, .japanese, .korean, .chineseSimplified, .chineseTraditional
    ]

    public var bcp47: String {
        switch self {
        case .system: return "en"
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portugueseBrazil: return "pt-BR"
        case .dutch: return "nl"
        case .arabic: return "ar"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .chineseSimplified: return "zh-Hans"
        case .chineseTraditional: return "zh-Hant"
        }
    }

    public var localeIdentifier: String { bcp47 }

    public var isRTL: Bool { self == .arabic }

    public var nativeName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portugueseBrazil: return "Português (Brasil)"
        case .dutch: return "Nederlands"
        case .arabic: return "العربية"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        }
    }
}

public enum LanguageResolver {
    /// System-first: if the user picked a language, use it; otherwise match preferred language tags.
    public static func resolve(preference: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        if preference != .system { return preference }
        return match(preferredLanguages) ?? .english
    }

    public static func match(_ preferredLanguages: [String]) -> AppLanguage? {
        for tag in preferredLanguages {
            let lower = tag.replacingOccurrences(of: "_", with: "-").lowercased()
            if lower.hasPrefix("zh-hant") || lower.hasPrefix("zh-tw") || lower.hasPrefix("zh-hk") || lower.hasPrefix("zh-mo") {
                return .chineseTraditional
            }
            if lower.hasPrefix("zh") { return .chineseSimplified }
            if lower.hasPrefix("pt-br") || lower.hasPrefix("pt-br") { return .portugueseBrazil }
            if lower.hasPrefix("pt") { return .portugueseBrazil }
            if lower.hasPrefix("es") { return .spanish }
            if lower.hasPrefix("fr") { return .french }
            if lower.hasPrefix("de") { return .german }
            if lower.hasPrefix("it") { return .italian }
            if lower.hasPrefix("nl") { return .dutch }
            if lower.hasPrefix("ar") { return .arabic }
            if lower.hasPrefix("ja") { return .japanese }
            if lower.hasPrefix("ko") { return .korean }
            if lower.hasPrefix("en") { return .english }
        }
        return nil
    }
}

public enum L10n {
    public static func string(_ key: String, language: AppLanguage) -> String {
        let lang = language == .system ? .english : language
        if let value = table[key]?[lang] { return value }
        return table[key]?[.english] ?? key
    }

    /// Every shipped UI language (not `.system`) must have this key.
    public static let probeKey = "done"

    public static var translatedLanguages: [AppLanguage] {
        AppLanguage.displayOrder
    }
}

// MARK: - Table

extension L10n {
    static let table: [String: [AppLanguage: String]] = {
        func row(_ en: String, _ es: String, _ fr: String, _ de: String, _ it: String, _ pt: String, _ nl: String, _ ar: String, _ ja: String, _ ko: String, _ zhHans: String, _ zhHant: String) -> [AppLanguage: String] {
            [
                .english: en, .spanish: es, .french: fr, .german: de, .italian: it,
                .portugueseBrazil: pt, .dutch: nl, .arabic: ar, .japanese: ja,
                .korean: ko, .chineseSimplified: zhHans, .chineseTraditional: zhHant
            ]
        }
        return [
            "done": row("Done", "Hecho", "OK", "Fertig", "Fine", "Concluído", "Gereed", "تم", "完了", "완료", "完成", "完成"),
            "cancel": row("Cancel", "Cancelar", "Annuler", "Abbrechen", "Annulla", "Cancelar", "Annuleren", "إلغاء", "キャンセル", "취소", "取消", "取消"),
            "settings": row("Settings", "Ajustes", "Réglages", "Einstellungen", "Impostazioni", "Ajustes", "Instellingen", "الإعدادات", "設定", "설정", "设置", "設定"),
            "close": row("Close", "Cerrar", "Fermer", "Schließen", "Chiudi", "Fechar", "Sluiten", "إغلاق", "閉じる", "닫기", "关闭", "關閉"),
            "units": row("Units", "Unidades", "Unités", "Einheiten", "Unità", "Unidades", "Eenheden", "الوحدات", "単位", "단위", "单位", "單位"),
            "follow_locale": row("Follow locale", "Usar configuración regional", "Suivre les réglages régionaux", "Gebietsschema folgen", "Usa impostazioni locali", "Usar localização", "Volg landinstelling", "اتباع الإعدادات الإقليمية", "地域設定に合わせる", "지역 설정 따르기", "跟随地区设置", "跟隨地區設定"),
            "temperature": row("Temperature", "Temperatura", "Température", "Temperatur", "Temperatura", "Temperatura", "Temperatuur", "درجة الحرارة", "気温", "기온", "温度", "溫度"),
            "wind": row("Wind", "Viento", "Vent", "Wind", "Vento", "Vento", "Wind", "الرياح", "風", "바람", "风", "風"),
            "precipitation": row("Precipitation", "Precipitación", "Précipitations", "Niederschlag", "Precipitazioni", "Precipitação", "Neerslag", "هطول", "降水", "강수", "降水", "降水"),
            "appearance": row("Appearance", "Apariencia", "Apparence", "Erscheinungsbild", "Aspetto", "Aparência", "Weergave", "المظهر", "外観", "모양", "外观", "外觀"),
            "language": row("Language", "Idioma", "Langue", "Sprache", "Lingua", "Idioma", "Taal", "اللغة", "言語", "언어", "语言", "語言"),
            "language_system": row("System", "Sistema", "Système", "System", "Sistema", "Sistema", "Systeem", "النظام", "システム", "시스템", "系统", "系統"),
            "motion": row("Motion", "Movimiento", "Mouvement", "Bewegung", "Movimento", "Movimento", "Beweging", "الحركة", "モーション", "동작", "动态效果", "動態效果"),
            "motion_system": row("Follow System", "Seguir el sistema", "Suivre le système", "System folgen", "Segui il sistema", "Seguir o sistema", "Volg systeem", "اتباع النظام", "システムに合わせる", "시스템 따르기", "跟随系统", "跟隨系統"),
            "motion_always": row("Always animate", "Animar siempre", "Toujours animer", "Immer animieren", "Anima sempre", "Sempre animar", "Altijd animeren", "تحريك دائمًا", "常にアニメーション", "항상 애니메이션", "始终动画", "一律動畫"),
            "motion_never": row("Reduce motion", "Reducir movimiento", "Réduire les animations", "Bewegung reduzieren", "Riduci movimento", "Reduzir movimento", "Beweging verminderen", "تقليل الحركة", "視差効果を減らす", "동작 줄이기", "减弱动态效果", "減少動態效果"),
            "chrome": row("Chrome", "Interfaz", "Interface", "Oberfläche", "Interfaccia", "Interface", "Interface", "الواجهة", "外枠", "크롬", "界面", "介面"),
            "follow_scene": row("Follow scene", "Seguir la escena", "Suivre la scène", "Szene folgen", "Segui la scena", "Seguir a cena", "Volg scène", "اتباع المشهد", "シーンに合わせる", "장면 따르기", "跟随天气场景", "跟隨天氣場景"),
            "system": row("System", "Sistema", "Système", "System", "Sistema", "Sistema", "Systeem", "النظام", "システム", "시스템", "系统", "系統"),
            "light": row("Light", "Claro", "Clair", "Hell", "Chiaro", "Claro", "Licht", "فاتح", "ライト", "라이트", "浅色", "淺色"),
            "dark": row("Dark", "Oscuro", "Sombre", "Dunkel", "Scuro", "Escuro", "Donker", "داكن", "ダーク", "다크", "深色", "深色"),
            "grade_sun": row("Grade sky to the place’s sun", "Cielo según el sol del lugar", "Ciel selon le soleil du lieu", "Himmel nach Ortsonne", "Cielo in base al sole del luogo", "Céu conforme o sol do local", "Lucht naar lokale zon", "تدرج السماء حسب شمس المكان", "その場所の太陽に合わせて空を着色", "해당 장소의 태양에 맞춰 하늘 표현", "按当地太阳为天空着色", "依當地太陽為天空上色"),
            "menu_bar": row("Menu Bar", "Barra de menús", "Barre des menus", "Menüleiste", "Barra dei menu", "Barra de menus", "Menubalk", "شريط القائمة", "メニューバー", "메뉴 막대", "菜单栏", "選單列"),
            "shows": row("Shows", "Muestra", "Affiche", "Zeigt", "Mostra", "Mostra", "Toont", "يعرض", "表示", "표시", "显示", "顯示"),
            "selected_city": row("Selected city", "Ciudad seleccionada", "Ville sélectionnée", "Ausgewählte Stadt", "Città selezionata", "Cidade selecionada", "Geselecteerde stad", "المدينة المحددة", "選択中の都市", "선택한 도시", "当前城市", "目前城市"),
            "data": row("Data", "Datos", "Données", "Daten", "Dati", "Dados", "Gegevens", "البيانات", "データ", "데이터", "数据", "資料"),
            "data_blurb": row(
                "Forecasts come from Open-Meteo, which combines national weather models. No API key is used. Location is sent only as coordinates to fetch weather.",
                "Los pronósticos provienen de Open-Meteo, que combina modelos meteorológicos nacionales. No se usa clave de API.",
                "Les prévisions viennent d’Open-Meteo, qui combine des modèles nationaux. Aucune clé API n’est utilisée.",
                "Vorhersagen stammen von Open-Meteo, das nationale Wettermodelle kombiniert. Es wird kein API-Schlüssel verwendet.",
                "Le previsioni arrivano da Open-Meteo, che combina modelli nazionali. Nessuna chiave API.",
                "As previsões vêm do Open-Meteo, que combina modelos nacionais. Nenhuma chave de API é usada.",
                "Voorspellingen komen van Open-Meteo, dat nationale weermodellen combineert. Geen API-sleutel.",
                "التوقعات من Open-Meteo الذي يجمع نماذج وطنية. لا يُستخدم مفتاح واجهة.",
                "予報は各国の気象モデルを組み合わせる Open-Meteo から取得します。API キーは使いません。",
                "예보는 국가 기상 모델을 결합하는 Open-Meteo에서 가져옵니다. API 키가 없습니다.",
                "预报来自 Open-Meteo，它会融合各国气象模式。无需 API 密钥。",
                "預報來自 Open-Meteo，會融合各國氣象模式。無需 API 金鑰。"
            ),
            "inspector": row("Inspector", "Inspector", "Inspecteur", "Inspektor", "Ispettore", "Inspetor", "Inspector", "المفتش", "インスペクタ", "검사기", "检查器", "檢查器"),
            "models": row("Models", "Modelos", "Modèles", "Modelle", "Modelli", "Modelos", "Modellen", "النماذج", "モデル", "모델", "模式", "模式"),
            "atmosphere": row("Atmosphere", "Atmósfera", "Atmosphère", "Atmosphäre", "Atmosfera", "Atmosfera", "Atmosfeer", "الغلاف الجوي", "大気", "대기", "大气", "大氣"),
            "solar": row("Solar", "Solar", "Solaire", "Solar", "Solare", "Solar", "Zon", "شمسي", "日射", "일사", "太阳辐射", "太陽輻射"),
            "uncertainty": row("Uncertainty", "Incertidumbre", "Incertitude", "Unsicherheit", "Incertezza", "Incerteza", "Onzekerheid", "عدم اليقين", "不確実性", "불확실성", "不确定性", "不確定性"),
            "sounding": row("Sounding", "Sondeo", "Sondage", "Sondierung", "Sondaggio", "Sondagem", "Sonde", "سبر", "サウンディング", "연직 탐사", "探空", "探空"),
            "uv_index": row("UV Index", "Índice UV", "Indice UV", "UV-Index", "Indice UV", "Índice UV", "UV-index", "مؤشر الأشعة فوق البنفسجية", "UV指数", "자외선 지수", "紫外线指数", "紫外線指數"),
            "feels_like": row("Feels Like", "Sensación", "Ressenti", "Gefühlt", "Percepita", "Sensação", "Gevoelstemperatuur", "الحرارة المحسوسة", "体感", "체감", "体感", "體感"),
            "humidity": row("Humidity", "Humedad", "Humidité", "Luftfeuchtigkeit", "Umidità", "Umidade", "Luchtvochtigheid", "الرطوبة", "湿度", "습도", "湿度", "濕度"),
            "visibility": row("Visibility", "Visibilidad", "Visibilité", "Sichtweite", "Visibilità", "Visibilidade", "Zicht", "الرؤية", "視程", "가시거리", "能见度", "能見度"),
            "pressure": row("Pressure", "Presión", "Pression", "Luftdruck", "Pressione", "Pressão", "Luchtdruk", "الضغط", "気圧", "기압", "气压", "氣壓"),
            "sun_moon": row("Sun & Moon", "Sol y luna", "Soleil et lune", "Sonne & Mond", "Sole e luna", "Sol e lua", "Zon en maan", "الشمس والقمر", "太陽と月", "해와 달", "日月", "日月"),
            "air_quality": row("Air Quality", "Calidad del aire", "Qualité de l’air", "Luftqualität", "Qualità dell’aria", "Qualidade do ar", "Luchtkwaliteit", "جودة الهواء", "大気質", "대기질", "空气质量", "空氣品質"),
            "search_cities": row("Search cities", "Buscar ciudades", "Rechercher des villes", "Städte suchen", "Cerca città", "Buscar cidades", "Zoek steden", "البحث عن مدن", "都市を検索", "도시 검색", "搜索城市", "搜尋城市"),
            "my_location": row("My Location", "Mi ubicación", "Ma position", "Eigener Standort", "La mia posizione", "Minha localização", "Mijn locatie", "موقعي", "現在地", "내 위치", "我的位置", "我的位置"),
            "cities": row("Cities", "Ciudades", "Villes", "Städte", "Città", "Cidades", "Steden", "المدن", "都市", "도시", "城市", "城市"),
            "popular": row("Popular", "Populares", "Populaires", "Beliebt", "Popolari", "Populares", "Populair", "شائع", "人気", "인기", "热门", "熱門"),
            "add": row("Add", "Añadir", "Ajouter", "Hinzufügen", "Aggiungi", "Adicionar", "Voeg toe", "إضافة", "追加", "추가", "添加", "加入"),
            "remove": row("Remove", "Eliminar", "Supprimer", "Entfernen", "Rimuovi", "Remover", "Verwijderen", "إزالة", "削除", "제거", "移除", "移除"),
            "hourly": row("Hourly", "Por hora", "Heure par heure", "Stündlich", "Oraria", "Por hora", "Per uur", "ساعي", "1時間ごと", "시간별", "逐小时", "逐小時"),
            "forecast_16": row("16-Day Forecast", "Pronóstico de 16 días", "Prévisions sur 16 jours", "16-Tage-Vorhersage", "Previsione a 16 giorni", "Previsão de 16 dias", "16-daagse verwachting", "توقعات 16 يومًا", "16日間予報", "16일 예보", "16 天预报", "16 天預報"),
            "today": row("Today", "Hoy", "Aujourd’hui", "Heute", "Oggi", "Hoje", "Vandaag", "اليوم", "今日", "오늘", "今天", "今天"),
            "tomorrow": row("Tomorrow", "Mañana", "Demain", "Morgen", "Domani", "Amanhã", "Morgen", "غدًا", "明日", "내일", "明天", "明天"),
            "now": row("Now", "Ahora", "Maintenant", "Jetzt", "Ora", "Agora", "Nu", "الآن", "現在", "지금", "现在", "現在"),
            "refresh": row("Refresh", "Actualizar", "Actualiser", "Aktualisieren", "Aggiorna", "Atualizar", "Vernieuwen", "تحديث", "更新", "새로 고침", "刷新", "重新整理"),
            "enable_location": row("Enable Location", "Activar ubicación", "Activer la localisation", "Ortung aktivieren", "Attiva posizione", "Ativar localização", "Locatie inschakelen", "تفعيل الموقع", "位置情報を許可", "위치 사용", "启用定位", "啟用定位"),
            "location_needed": row("My Location needs permission", "Mi ubicación necesita permiso", "Ma position nécessite une autorisation", "Eigener Standort braucht eine Freigabe", "La mia posizione richiede l’autorizzazione", "Minha localização precisa de permissão", "Mijn locatie heeft toestemming nodig", "موقعي يحتاج إلى إذن", "現在地には許可が必要です", "내 위치를 쓰려면 권한이 필요합니다", "使用“我的位置”需要授权", "使用「我的位置」需要授權"),
            "chance_today": row("chance today", "de probabilidad hoy", "de risque aujourd’hui", "Wahrscheinlichkeit heute", "di probabilità oggi", "de chance hoje", "kans vandaag", "احتمال اليوم", "今日の確率", "오늘 확률", "今日概率", "今日機率"),
            "gusts": row("Gusts", "Ráfagas", "Rafales", "Böen", "Raffiche", "Rajadas", "Windstoten", "هبات", "突風", "돌풍", "阵风", "陣風"),
            "dew_point": row("Dew point", "Punto de rocío", "Point de rosée", "Taupunkt", "Punto di rugiada", "Ponto de orvalho", "Dauwpunt", "نقطة الندى", "露点", "이슬점", "露点", "露點"),
            "rising": row("Rising", "En aumento", "En hausse", "Steigend", "In aumento", "Subindo", "Stijgend", "مرتفع", "上昇", "상승", "上升", "上升"),
            "falling": row("Falling", "En descenso", "En baisse", "Fallend", "In calo", "Caindo", "Dalend", "منخفض", "下降", "하강", "下降", "下降"),
            "steady": row("Steady", "Estable", "Stable", "Beständig", "Stabile", "Estável", "Stabiel", "مستقر", "安定", "안정", "平稳", "平穩"),
            "clear": row("Clear", "Despejado", "Dégagé", "Klar", "Sereno", "Limpo", "Helder", "صافٍ", "快晴", "맑음", "晴", "晴"),
            "good": row("Good", "Buena", "Bon", "Gut", "Buona", "Boa", "Goed", "جيدة", "良好", "좋음", "优", "優"),
            "updated_just_now": row("Updated just now", "Actualizado ahora", "Actualisé à l’instant", "Gerade aktualisiert", "Aggiornato ora", "Atualizado agora", "Zojuist bijgewerkt", "حُدِّث الآن", "たった今更新", "방금 업데이트됨", "刚刚更新", "剛剛更新"),
            "open_nimbus": row("Open Nimbus", "Abrir Nimbus", "Ouvrir Nimbus", "Nimbus öffnen", "Apri Nimbus", "Abrir Nimbus", "Nimbus openen", "فتح Nimbus", "Nimbus を開く", "Nimbus 열기", "打开 Nimbus", "打開 Nimbus"),
            "models_help": row(
                "The main forecast stays on Best Match. These overlays are for comparison only.",
                "El pronóstico principal sigue en Best Match. Estas curvas son solo para comparar.",
                "La prévision principale reste sur Best Match. Ces courbes sont uniquement comparatives.",
                "Die Hauptvorhersage bleibt bei Best Match. Diese Kurven dienen nur dem Vergleich.",
                "La previsione principale resta su Best Match. Questi overlay sono solo un confronto.",
                "A previsão principal permanece em Best Match. Estas curvas são só para comparação.",
                "De hoofdverwachting blijft Best Match. Deze lijnen zijn alleen ter vergelijking.",
                "التوقع الرئيسي يبقى على Best Match. هذه المنحنيات للمقارنة فقط.",
                "本予報は Best Match のままです。これらの重ね合わせは比較用です。",
                "기본 예보는 Best Match를 유지합니다. 이 겹침은 비교용입니다.",
                "主预报仍使用 Best Match。这些叠加仅供比较。",
                "主預報仍使用 Best Match。這些疊加僅供比較。"
            )
        ]
    }()
}
