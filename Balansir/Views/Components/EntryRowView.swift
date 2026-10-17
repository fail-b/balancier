import SwiftUI

struct EntryRow: View {
    let entry: EntryModel
    var isLast: Bool = false
    /// Тап по чипу тега (поиск по тегу на Главной). nil — чипы не нажимаются.
    var onTagTap: ((TagModel) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.m) {
                iconView
                    .frame(width: Theme.Row.iconSize, height: Theme.Row.iconSize)

                VStack(alignment: .leading, spacing: Theme.Row.textSpacing) {
                    // Название и чипы тегов; не помещается — ужимаются чипы, а не название.
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(entry.displayTitle)
                            .font(Theme.Font.rowTitle)
                            .foregroundStyle(Theme.Colors.ink)
                            .lineLimit(1)
                            .layoutPriority(1)
                        ForEach(entry.tags) { tag in
                            TagChip(name: tag.name, action: onTagTap.map { tap in { tap(tag) } })
                        }
                    }
                    // Счёт · “заметка”; не помещается — обрезается заметка.
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(entry.displayAccount)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.ink2)
                            .lineLimit(1)
                            .layoutPriority(1)
                        if let note = entry.displayNote {
                            Text(verbatim: "·")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Colors.ink2)
                            Text(verbatim: note)
                                .font(Theme.Font.rowNote)
                                .foregroundStyle(Theme.Colors.ink2)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Theme.Row.textSpacing) {
                    Text(amountString)
                        .font(Theme.Font.rowAmount)
                        .foregroundStyle(amountColor)
                    Text(entry.date, style: .time)
                        .font(Theme.Font.time)
                        .foregroundStyle(Theme.Colors.ink2)
                }
                // Сумма и время не ужимаются тегами и длинной заметкой.
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Row.verticalPadding)

            if !isLast {
                Rectangle()
                    .fill(Theme.Colors.separator)
                    .frame(height: Theme.Size.hairline)
                    .padding(.leading, Theme.Row.separatorInset)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if entry.type == .transfer {
            Circle()
                .fill(Theme.Colors.fill)
                .overlay {
                    AppIcon.image(named: AppIcon.transfer)
                        .font(Theme.Font.rowIcon)
                        .foregroundStyle(Theme.Colors.transfer)
                }
        } else if entry.type == .debt, let counterparty = entry.counterparty {
            CounterpartyIcon(counterparty: counterparty, size: Theme.Row.iconSize)
        } else if let category = entry.category {
            CategoryIcon(category: category, size: Theme.Row.iconSize)
        } else {
            Circle()
                .fill(Theme.Colors.fill)
        }
    }

    private var amountString: String {
        let formatted = MoneyFormatter.format(entry.amount, currency: entry.currency)
        switch entry.type {
        case .expense: return "\u{2212}\(formatted)"
        case .income: return "+\(formatted)"
        case .transfer: return formatted
        // Долг: отправил — «−», пришли — «+» (§4.11).
        case .debt: return entry.debtDirection == .sent ? "\u{2212}\(formatted)" : "+\(formatted)"
        }
    }

    private var amountColor: Color {
        switch entry.type {
        case .expense: return Theme.Colors.ink
        case .income: return Theme.Colors.income
        case .transfer: return Theme.Colors.ink
        // Пришедший долг — не доход, поэтому не `income`.
        case .debt: return Theme.Colors.ink
        }
    }
}
