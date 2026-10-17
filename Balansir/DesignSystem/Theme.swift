import SwiftUI

enum Theme {
    enum Colors {
        // Семантические токены UI
        static let accent = Color("Colors/accent")
        static let background = Color("Colors/background")
        static let card = Color("Colors/card")
        static let ink = Color("Colors/ink")
        static let ink2 = Color("Colors/ink2")
        /// Третичный текст, светлее `ink2`.
        static let ink3 = Color("Colors/ink3")
        static let separator = Color("Colors/separator")
        static let fill = Color("Colors/fill")
        static let fill2 = Color("Colors/fill2")
        static let key = Color("Colors/key")
        static let selection = Color("Colors/selection")
        // Типы операций
        static let expense = Color("Colors/expense")
        static let income = Color("Colors/income")
        static let transfer = Color("Colors/transfer")
        // Долги (§4.11): «вам должны» (+) и «вы должны» (−)
        static let debtOwedToMe = Color("Colors/debtOwedToMe")
        static let debtIOwe = Color("Colors/debtIOwe")
        // Служебные
        static let negativeBalance = Color("Colors/negativeBalance")
        static let fallback = Color("Colors/fallback")
        static let shadow = Color("Colors/shadow")
        /// Белый текст/иконка на цветной заливке (напр. кнопка «Удалить»)
        static let onColor = Color("Colors/onColor")
        // Экран запуска (`BalansirSplashCoinView`). `splashBackground` также указан
        // в Info.plist (UILaunchScreen → UIColorName) — переименовывать вместе с ним.
        static let splashBackground = Color("Colors/splashBackground")
        static let splashMark = Color("Colors/splashMark")
        static let splashText = Color("Colors/splashText")
    }

    /// Цвет суммы долга по знаку (§4.11): `+` — `debtOwedToMe`, `−` — `debtIOwe`, 0 — `ink2`.
    static func debtColor(for amount: Decimal) -> Color {
        if amount > 0 { return Colors.debtOwedToMe }
        if amount < 0 { return Colors.debtIOwe }
        return Colors.ink2
    }

    /// Мягкая тень плавающих стеклянных элементов (таб-бар).
    enum Shadow {
        static let color = Colors.shadow
        static let radius: CGFloat = 18
        static let y: CGFloat = 6
    }

    /// Размеры управляющих элементов.
    enum Size {
        /// Высота строки поиска и круглых стеклянных кнопок в шапке (44 pt, §4.1.4).
        static let searchBar: CGFloat = 44
        /// Запас под мини-бар (`tabViewBottomAccessory`) внизу скроллов вкладок.
        /// Когда таб-бар свёрнут и мини-бар встаёт в одну строку с ним, система не учитывает
        /// мини-бар в нижнем отступе — без запаса последняя строка уходит под него.
        static let bottomAccessoryClearance: CGFloat = 56
        /// Толщина разделителя строк в карточках-списках.
        static let hairline: CGFloat = 0.5
        /// Минимальный масштаб сумм в сводке у таб-бара — длинная сумма ужимается, а не обрезается.
        static let summaryMinScale: CGFloat = 0.7
        /// Минимальный масштаб заголовка шапки Главной («Все операции», «Сентябрь 2025»):
        /// на узких экранах ужимается, а не обрезается и не наезжает на капсулу поиска.
        static let headerTitleMinScale: CGFloat = 0.7
        /// Зазор между заголовком месяца и стрелкой в шапке Главной.
        static let headerChevronGap: CGFloat = 4
    }

    /// Строка операции `EntryRow` (§4.2).
    enum Row {
        /// Иконка категории/перевода.
        static let iconSize: CGFloat = 40
        /// Вертикальный паддинг строки.
        static let verticalPadding: CGFloat = 10
        /// Зазор между названием и подписью, суммой и временем.
        static let textSpacing: CGFloat = 2
        /// Отступ разделителя слева: паддинг 16 + иконка 40 + зазор 12.
        static let separatorInset: CGFloat = 68
    }

    /// Hero-карточка Главной (§4.1): вертикальный паддинг (горизонтальный — `Spacing.xl`).
    enum Hero {
        static let verticalPadding: CGFloat = 18
    }

    /// Экран «Контрагенты» и форма контрагента (§4.11).
    enum Counterparties {
        /// Ячейка выбора цвета/иконки в форме.
        static let pickerCellHeight: CGFloat = 36
        static let pickerIconSize: CGFloat = 36
    }

    /// Шит новой операции (§4.7).
    enum AddEntry {
        /// Ячейка быстрого выбора категории: ширина, рамка под кольцо выбора, иконка, кольцо, зазор до подписи.
        static let categoryCellWidth: CGFloat = 68
        static let categoryRingFrame: CGFloat = 52
        static let categoryIconSize: CGFloat = 46
        static let categoryRingWidth: CGFloat = 2
        static let categoryLabelGap: CGFloat = 6
    }
    /// Теги (§4.2, §4.7): карусель в шите и чипы в строке ленты.
    enum TagSize {
        /// Ячейка карусели в шите.
        static let carouselHeight: CGFloat = 32
        static let carouselHorizontalPadding: CGFloat = 12
        /// Поле нового тега на месте «+»: ширина и обводка.
        static let newTagFieldWidth: CGFloat = 140
        static let newTagFieldBorder: CGFloat = 1.5
        /// Чип в строке ленты.
        static let rowHorizontalPadding: CGFloat = 6
        static let rowVerticalPadding: CGFloat = 2
    }
    /// Свайп влево по строке операции → удаление (§4.2).
    enum Swipe {
        /// Ширина открытой кнопки «Удалить».
        static let actionWidth: CGFloat = 88
        /// Длинный свайп: доля ширины строки, за которой отпускание удаляет операцию.
        static let fullSwipeFraction: CGFloat = 0.5
        /// Строка уезжает влево перед удалением, с.
        static let removeDuration: Double = 0.2
        /// Сколько висит плашка «Удалено · Отменить», с.
        static let undoDuration: Double = 4
    }

    /// Экран «Статистика» (§4.4).
    enum Stats {
        /// Высота области столбиков по дням.
        static let chartHeight: CGFloat = 110
        /// Зазор между столбиками.
        static let barGap: CGFloat = 3
        static let barRadius: CGFloat = 2
        /// Минимальная высота столбика (и высота столбиков будущих дней).
        static let barMinHeight: CGFloat = 4
        /// Цветная точка категории в списке.
        static let categoryDot: CGFloat = 10
        /// Высота полоски прогресса категории.
        static let progressHeight: CGFloat = 4
        /// Ширина колонки суммы (выравнивание вправо).
        static let amountColumnWidth: CGFloat = 92
        /// Отступ разделителя строк слева (под текст, после точки).
        static let separatorInset: CGFloat = 36
    }

    /// Экран «Счета» (§4.5) и шит «Новый счёт» (§4.6).
    enum Accounts {
        /// Цветная «карточка» счёта в списке.
        static let colorCardWidth: CGFloat = 34
        static let colorCardHeight: CGFloat = 23
        /// Зазор между карточкой и названием.
        static let textGap: CGFloat = 14
        /// Отступ разделителя слева: паддинг 16 + карточка 34 + зазор 14.
        static let separatorInset: CGFloat = 64
        /// Кружок цвета в шите.
        static let colorDot: CGFloat = 30
        /// Кольцо выбранного цвета: толщина и зазор до кружка.
        static let colorRingWidth: CGFloat = 2
        static let colorRingGap: CGFloat = 3
        /// Кнопка «Добавить» в шите.
        static let addButtonHeight: CGFloat = 54
        /// Прозрачность неактивной кнопки «Добавить».
        static let disabledOpacity: Double = 0.45
        /// Поле «Баланс».
        static let balanceFieldHeight: CGFloat = 52
        /// Сегмент «Карта · Наличные · Вклад»: высота активной капсулы и её тень.
        static let segmentHeight: CGFloat = 36
        static let segmentShadowRadius: CGFloat = 4
        static let segmentShadowY: CGFloat = 1
    }

    /// Онбординг (§4.9).
    enum Onboarding {
        /// Высота сегментов прогресса.
        static let progressHeight: CGFloat = 4
        /// Пример hero-карточки на шаге 1: отступы, полоса категорий, тень.
        static let demoCardHorizontalPadding: CGFloat = 20
        static let demoCardVerticalPadding: CGFloat = 18
        static let demoBarHeight: CGFloat = 10
        static let demoBarRadius: CGFloat = 5
        static let demoBarGap: CGFloat = 2
        static let demoShadowRadius: CGFloat = 24
        static let demoShadowY: CGFloat = 8
    }

    /// Анимация запуска «Монета» `BalansirSplashCoinView` (от дизайнера, 2026-10-12), ~1,5 с.
    enum Splash {
        /// Диаметр знака (монеты).
        static let markDiameter: CGFloat = 92
        /// Зазор между половинками знака — доля диаметра (60/520 по мастеру иконки 1024).
        static let markGapRatio: CGFloat = 60 / 520
        /// Прозрачность нижней половинки знака.
        static let lowerHalfOpacity: Double = 0.5
        /// Зазор между знаком и словом «balansir».
        static let wordmarkSpacing: CGFloat = 24
        /// Межбуквенный интервал слова: −0,035 em при кегле 40.
        static let wordmarkTracking: CGFloat = -1.4
        /// Слово выезжает снизу на столько pt.
        static let wordmarkRise: CGFloat = 12
        /// Высота, с которой падает монета.
        static let dropHeight: CGFloat = 560
        /// Переворот монеты вокруг вертикальной оси: угол (два оборота) и перспектива.
        static let spinDegrees: Double = 720
        static let spinPerspective: CGFloat = 0.4
        /// Маленькие монетки, влетающие в знак: размер, стартовые смещения от центра,
        /// точка, в которой они исчезают, и масштаб в ней.
        static let dotSize: CGFloat = 14
        static let dotStarts: [CGSize] = [
            CGSize(width: -130, height: -150),
            CGSize(width: 140, height: -40),
            CGSize(width: -115, height: 120)
        ]
        static let dotTarget = CGSize(width: 0, height: 30)
        static let dotDepositScale: CGFloat = 0.4
        /// Задержка между монетками, с.
        static let dotStagger: Double = 0.08
        // Анимации шагов
        static let dropAnimation = SwiftUI.Animation.spring(response: 0.42, dampingFraction: 0.6)
        static let spinAnimation = SwiftUI.Animation.timingCurve(0.45, 0, 0.25, 1, duration: 0.52)
        static let dotAppearAnimation = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.6)
        static let dotDepositAnimation = SwiftUI.Animation.easeIn(duration: 0.34)
        static let splitAnimation = SwiftUI.Animation.spring(response: 0.48, dampingFraction: 0.6)
        static let wordmarkAnimation = SwiftUI.Animation.easeOut(duration: 0.34)
        /// Паузы после шагов, мс: падение → переворот → разделение → слово → конец.
        static let dropPause = 400
        static let spinPause = 520
        static let splitPause = 260
        static let wordmarkPause = 360
        /// Растворение сплэша при переходе в приложение.
        static let dismissAnimation = SwiftUI.Animation.easeOut(duration: 0.25)
    }

    /// Самописная цифровая клавиатура `NumpadView` (§4.6, §4.7).
    enum Numpad {
        static let keyHeight: CGFloat = 52
    }

    /// Жест «потянуть вниз» → поиск на Главной (§4.1.4).
    enum Pull {
        /// Оттяжка ленты вниз, при которой прогресс жеста достигает 1 (порог активации).
        static let threshold: CGFloat = 70
        /// «Подпрыгивание» лупы на пороге — сигнал «отпусти, будет поиск».
        static let magnifierScaleActive: CGFloat = 1.1
    }

    /// Анимации, общие для нескольких экранов.
    enum Animation {
        /// Морфинг лупы в строку поиска на Главной (§4.1.4): spring ~0.35 с, damping 0.8.
        static let searchMorph: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.8)
        /// Смена своей цифровой клавиатуры на системную в шите операции (§4.7).
        static let numpadToggle: SwiftUI.Animation = .easeInOut(duration: 0.25)
        /// Пауза перед прокруткой карусели к счёту после перехода со вкладки «Счета» (§4.5).
        static let revealDelay: Duration = .milliseconds(200)
    }

    enum Spacing {
        /// Зазор между подписью и суммой в сводке у таб-бара.
        static let xxs: CGFloat = 1
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 28
    }

    enum Radius {
        // Старые (используются в существующих View)
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        // Новые из дизайна
        static let card: CGFloat = 22
        static let hero: CGFloat = 26
        static let accountChip: CGFloat = 16
        static let sheet: CGFloat = 38
        static let accountSheet: CGFloat = 44
        static let search: CGFloat = 12
        static let balanceField: CGFloat = 14
        static let accountColorCard: CGFloat = 5
    }

    enum Font {
        static let screenTitle = SwiftUI.Font.system(size: 34, weight: .bold)
        static let heroAmount = SwiftUI.Font.system(size: 34, weight: .bold).monospacedDigit()
        static let amountInput = SwiftUI.Font.system(size: 60, weight: .bold).monospacedDigit()
        static let sheetTitle = SwiftUI.Font.system(size: 17, weight: .semibold)
        /// Бренд-бук: Headline 17 semibold.
        static let headline = SwiftUI.Font.system(size: 17, weight: .semibold)
        /// Бренд-бук: Body 17.
        static let body = SwiftUI.Font.system(size: 17)
        /// Сумма в строке списка (Body semibold, табличные цифры).
        static let bodyAmount = SwiftUI.Font.system(size: 17, weight: .semibold).monospacedDigit()
        static let sectionTitle = SwiftUI.Font.system(size: 15, weight: .semibold)
        static let rowTitle = SwiftUI.Font.system(size: 16, weight: .medium)
        static let rowAmount = SwiftUI.Font.system(size: 16, weight: .semibold)
        /// Заметка в строке операции — во второй строке после счёта, курсивом в кавычках “…” (§4.2).
        static let rowNote = SwiftUI.Font.system(size: 13).italic()
        /// Чип тега `#Тег` в строке операции (§4.2).
        static let tagChip = SwiftUI.Font.system(size: 13, weight: .medium)
        /// Ячейка карусели тегов в шите (§4.7).
        static let tagCarousel = SwiftUI.Font.system(size: 15, weight: .medium)
        /// Подпись ячейки быстрого выбора категории в шите: обычная и выбранная.
        static let categoryCellLabel = SwiftUI.Font.system(size: 11)
        static let categoryCellLabelSelected = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let caption = SwiftUI.Font.system(size: 13)
        static let time = SwiftUI.Font.system(size: 12)
        /// Иконка перевода в строке операции и корзина в свайпе.
        static let rowIcon = SwiftUI.Font.system(size: 18)
        static let swipeActionIcon = SwiftUI.Font.system(size: 18)
        /// Плашка «Удалено · Отменить».
        static let toast = SwiftUI.Font.system(size: 15, weight: .medium)
        static let toastAction = SwiftUI.Font.system(size: 15, weight: .semibold)
        /// Название приложения на первом шаге онбординга (§4.9).
        static let onboardingBrand = SwiftUI.Font.system(size: 40, weight: .bold)
        /// Слово «balansir» на экране запуска — фирменный шрифт Onest SemiBold
        /// (`Resources/Fonts`, Info.plist → UIAppFonts). Размер фиксированный: логотип не растёт с Dynamic Type.
        static let splashWordmark = SwiftUI.Font.custom("Onest-SemiBold", fixedSize: 40)
        /// Подпись версии внизу Настроек (§4.8).
        static let appVersion = SwiftUI.Font.system(size: 12)
        static let searchField = SwiftUI.Font.system(size: 17)
        /// Заголовок шита «Новый счёт» (§4.6).
        static let accountSheetTitle = SwiftUI.Font.system(size: 20, weight: .bold)
        /// Кнопка-действие во всю ширину («Добавить», «+ Добавить счёт»).
        static let actionButton = SwiftUI.Font.system(size: 17, weight: .semibold)
        /// Клавиши `NumpadView`: цифры/знаки и иконка ⌫.
        static let numpadKey = SwiftUI.Font.system(size: 26, weight: .medium)
        static let numpadIcon = SwiftUI.Font.system(size: 22)
        static let tabLabel = SwiftUI.Font.system(size: 10, weight: .semibold)
        /// Сводка у таб-бара (§3): подпись над суммой, основная сумма слева, вторая справа.
        static let summaryLabel = SwiftUI.Font.system(size: 13)
        static let summaryValue = SwiftUI.Font.system(size: 20, weight: .bold).monospacedDigit()
        static let summarySecondary = SwiftUI.Font.system(size: 17, weight: .medium).monospacedDigit()

        // Трекинг применяется через .tracking() на Text-view
        enum Tracking {
            static let screenTitle: CGFloat = -0.8
            static let heroAmount: CGFloat = -1
            static let amountInput: CGFloat = -2
        }
    }

    enum Palette {
        /// Цвета счёта в шите «Новый счёт» (§4.6) — 8 кружков.
        static let accountHexColors: [String] = [
            "#4CAF50", "#FFDD00", "#EF3124", "#009FDF",
            "#3F51B5", "#9B59B6", "#FF8C42", "#1C1C1E",
        ]
        /// Цвета категорий.
        static let hexColors: [String] = [
            "#4CAF50", "#FFDD00", "#EF3124",
            "#009FDF", "#3F51B5", "#9B59B6",
            "#FF8C42", "#1C1C1E", "#4A90D9",
            "#FF6B6B", "#4ECDC4", "#45B7D1",
            "#96CEB4", "#DDA0DD", "#F7DC6F",
            "#1ABC9C", "#E91E63", "#607D8B",
        ]
    }
}
