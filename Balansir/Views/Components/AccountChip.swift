import SwiftUI

/// Двухстрочная карточка счёта в карусели-фильтре на Главной (§4.1.3):
/// метка + название, под ним текущий баланс в компактном формате.
struct AccountChip: View {
    let title: String
    /// Цвет метки счёта (данные, `colorHex`). У «Все» метки нет.
    let colorHex: String?
    let balance: Decimal
    let isActive: Bool
    /// Карточка долга (чип «Долги», контрагент, §4.11): сумма со знаком «+»/«−» и цветом долга.
    var isDebt: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let hex = colorHex {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: hex) ?? Theme.Colors.fallback)
                            .frame(width: 12, height: 8)
                    }
                    Text(title)
                        .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(titleColor)
                }
                Text(isDebt ? MoneyFormatter.compactDebt(balance) : MoneyFormatter.compact(balance))
                    .font(Theme.Font.caption)
                    .monospacedDigit()
                    .foregroundStyle(balanceColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, Theme.Spacing.s)
            .frame(minWidth: 88, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.accountChip)
                    .fill(isActive ? Theme.Colors.ink : Theme.Colors.card)
            )
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private var titleColor: Color {
        isActive ? Theme.Colors.background : Theme.Colors.ink
    }

    private var balanceColor: Color {
        if isActive {
            // Активная карточка: тёмный фон, белый баланс (минус читается по знаку, цветом не выделяем).
            return Theme.Colors.background.opacity(0.7)
        }
        if isDebt { return Theme.debtColor(for: balance) }
        return balance < 0 ? Theme.Colors.negativeBalance : Theme.Colors.ink2
    }

    /// VoiceOver: «Название, баланс −N ₽» — символ валюты и минус VoiceOver читает словами языка.
    private var accessibilityLabel: String {
        if isDebt { return String(localized: "\(title), debt \(MoneyFormatter.debt(balance))") }
        return String(localized: "\(title), balance \(MoneyFormatter.balance(balance))")
    }
}
