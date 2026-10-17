import Foundation

/// Перевод сумм между `Decimal` (domain) и целым числом минимальных единиц валюты (хранение, Core Data v4):
/// 311,06 ₽ ↔ 31106. Число знаков после запятой — по ISO 4217 (у иены 0, у динара Кувейта 3, у остальных 2).
enum MinorUnits {
    /// Валюты без дробной части по ISO 4217.
    private static let zeroDigitCurrencies: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG",
        "RWF", "UGX", "UYI", "VND", "VUV", "XAF", "XOF", "XPF",
    ]
    /// Валюты с тремя знаками по ISO 4217.
    private static let threeDigitCurrencies: Set<String> = ["BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"]

    /// Знаков после запятой у валюты; неизвестная — 2.
    static func fractionDigits(for currency: String) -> Int {
        let code = currency.uppercased()
        if zeroDigitCurrencies.contains(code) { return 0 }
        if threeDigitCurrencies.contains(code) { return 3 }
        return 2
    }

    /// Сумма → минимальные единицы, с округлением до знаков валюты (половина — от нуля).
    static func toMinor(_ amount: Decimal, currency: String) -> Int64 {
        var scaled = amount * pow(Decimal(10), fractionDigits(for: currency))
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    /// Минимальные единицы → сумма.
    static func fromMinor(_ minor: Int64, currency: String) -> Decimal {
        Decimal(minor) / pow(Decimal(10), fractionDigits(for: currency))
    }

    /// Старое значение `Double` (Core Data v1–v3) → минимальные единицы. `Double` 311.06 хранится
    /// как 311.0599…, поэтому округляем в `Double`, а не переводим в `Decimal` напрямую.
    static func toMinor(legacy value: Double, currency: String) -> Int64 {
        let factor = pow(10.0, Double(fractionDigits(for: currency)))
        return Int64((value * factor).rounded())
    }
}
