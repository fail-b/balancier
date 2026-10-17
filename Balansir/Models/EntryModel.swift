import Foundation
import SwiftUI

struct EntryModel: Identifiable {
    let id: UUID
    var date: Date
    var type: EntryType
    var amount: Decimal
    var currency: String
    var note: String?
    /// Теги (§4.2). В шите ставится один; два бывают только у импортированных операций.
    var tags: [TagModel]
    var isRecurring: Bool
    var isSoftDeleted: Bool
    let createdAt: Date
    let updatedAt: Date
    var fromAccount: AccountModel?
    var toAccount: AccountModel?
    var category: CategoryModel?
    /// Контрагент операции-долга (§4.11); у остальных типов nil.
    var counterparty: CounterpartyModel? = nil
}

extension EntryModel {
    var displayTitle: String {
        switch type {
        case .expense: return category?.name ?? String(localized: "Expense")
        case .income: return category?.name ?? String(localized: "entry.type.income", defaultValue: "Income")
        case .transfer: return String(localized: "Transfer")
        case .debt: return counterparty?.name ?? String(localized: "Debt")
        }
    }

    /// Направление долга: есть счёт-источник — «Вы отправили», иначе — «Вам пришли». nil — не долг.
    var debtDirection: DebtDirection? {
        guard type == .debt else { return nil }
        return fromAccount != nil ? .sent : .received
    }

    /// Заметка для строки ленты: в кавычках “…”, в одну строку; nil, если заметки нет (§4.2).
    /// «#» не добавляется — так в ленте показываются теги.
    var displayNote: String? {
        let text = (note ?? "")
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return "\u{201C}\(text)\u{201D}"
    }

    // Для переводов возвращает «Откуда → Куда», иначе — имя счёта
    var displayAccount: String {
        switch type {
        case .expense: return fromAccount?.name ?? ""
        case .income: return toAccount?.name ?? ""
        case .transfer:
            let from = fromAccount?.name ?? ""
            let to = toAccount?.name ?? ""
            return "\(from) → \(to)"
        case .debt:
            // «Вы отправили · Тинькофф» / «Вам пришли · Тинькофф».
            let account = (fromAccount ?? toAccount)?.name ?? ""
            return "\(debtDirection?.title ?? "") · \(account)"
        }
    }
}
