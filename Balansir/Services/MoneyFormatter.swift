import Foundation

/// Форматирование денег по локали (§1 «Формат денег»): разделители, положение символа валюты
/// и сокращения «млн/млрд» берутся из `FormatStyle` локали, а не зашиты в русский.
/// Локаль — параметром: во View по умолчанию `.current`, в тестах — явная.
enum MoneyFormatter {
    private static let symbols: [String: String] = ["RUB": "₽", "USD": "$", "EUR": "€"]

    /// Символ валюты по ISO-коду (зависит от валюты счёта, не константа).
    static func symbol(for currency: String) -> String {
        symbols[currency] ?? currency
    }

    /// Форматирует абсолютное значение суммы. Знак (−/+) добавляет вызывающий код.
    /// До 100 — с копейками (если они есть), от 100 — без копеек.
    static func format(_ amount: Decimal, currency: String = "RUB", locale: Locale = .current) -> String {
        let absAmount = abs(amount)
        let fraction: ClosedRange<Int> = absAmount < 100 ? 0...2 : 0...0
        return absAmount.formatted(
            currencyStyle(currency, locale: locale).precision(.fractionLength(fraction))
        )
    }

    /// Баланс счёта со знаком: отрицательный — с «−» (U+2212), положительный — без «+».
    static func balance(_ amount: Decimal, currency: String = "RUB", locale: Locale = .current) -> String {
        (amount < 0 ? "\u{2212}" : "") + format(amount, currency: currency, locale: locale)
    }

    /// Долг со знаком (§4.11): «+500 ₽» — вам должны, «−177 219 ₽» — вы должны, «0 ₽» — без знака.
    static func debt(_ amount: Decimal, currency: String = "RUB", locale: Locale = .current) -> String {
        sign(of: amount) + format(amount, currency: currency, locale: locale)
    }

    /// Долг со знаком в компактном формате — для карусели (как `compact`, но и с «+»).
    static func compactDebt(_ amount: Decimal, currency: String = "RUB", locale: Locale = .current) -> String {
        sign(of: amount) + compact(abs(amount), currency: currency, locale: locale)
    }

    private static func sign(of amount: Decimal) -> String {
        if amount > 0 { return "+" }
        if amount < 0 { return "\u{2212}" }
        return ""
    }

    /// Компактный формат для карусели счетов (§1): до 999 999 — как `format`;
    /// от 1 млн — сокращение локали с 1 знаком («1,2 млн ₽», «₽1.2M», «1,2 Mio. ₽»). Знак минуса — U+2212.
    static func compact(_ amount: Decimal, currency: String = "RUB", locale: Locale = .current) -> String {
        let sign = amount < 0 ? "\u{2212}" : ""
        let absAmount = abs(amount)
        guard absAmount >= 1_000_000 else { return sign + format(absAmount, currency: currency, locale: locale) }
        return sign + absAmount.formatted(
            currencyStyle(currency, locale: locale)
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }

    // Узкий символ валюты: «₽» и в en, а не «RUB».
    private static func currencyStyle(_ currency: String, locale: Locale) -> Decimal.FormatStyle.Currency {
        Decimal.FormatStyle.Currency(code: currency, locale: locale).presentation(.narrow)
    }
}
