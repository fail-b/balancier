import Foundation

enum EntryType: String, CaseIterable {
    case expense = "expense"
    case income = "income"
    case transfer = "transfer"
    /// Долг (§4.11): счёт ↔ контрагент. Меняет баланс счёта, но не расход и не доход.
    case debt = "debt"

    var title: String {
        switch self {
        case .expense: return String(localized: "Expense")
        // Ключ отдельный: «Income» без уточнения — это «Доходы» (множественное), а тут «Доход».
        case .income: return String(localized: "entry.type.income", defaultValue: "Income")
        case .transfer: return String(localized: "Transfer")
        case .debt: return String(localized: "Debt")
        }
    }
}

/// Направление операции-долга (§4.11). В модели не хранится: «Я отправил» — у операции `fromAccount`,
/// «Мне пришли» — `toAccount`. Дал в долг или вернул — видно по итогу, отдельного флага нет.
enum DebtDirection: CaseIterable {
    case sent
    case received

    var title: String {
        switch self {
        case .sent: return String(localized: "I sent")
        case .received: return String(localized: "I received")
        }
    }
}

enum AccountType: String, CaseIterable {
    case debit = "debit"
    case credit = "credit"
    case cash = "cash"
    case savings = "savings"

    var title: String {
        switch self {
        case .debit: return String(localized: "Debit")
        case .credit: return String(localized: "Credit")
        case .cash: return String(localized: "Cash")
        case .savings: return String(localized: "Savings")
        }
    }

    var defaultIcon: String {
        switch self {
        case .debit: return "creditcard"
        case .credit: return "creditcard.fill"
        case .cash: return "banknote"
        case .savings: return "building.columns"
        }
    }
}

enum CategoryType: String, CaseIterable {
    case expense = "expense"
    case income = "income"

    var title: String {
        switch self {
        case .expense: return String(localized: "Expenses")
        case .income: return String(localized: "Income")
        }
    }
}
