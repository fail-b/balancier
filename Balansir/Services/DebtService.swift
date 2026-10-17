import Foundation

/// Долги по контрагентам (§4.11). Долг не хранится — считается из операций типа `debt`:
/// «Вы отправили» увеличивает долг контрагента передо мной, «Вам пришли» — уменьшает.
/// Знак: `+` — вам должны, `−` — вы должны.
enum DebtService {

    /// Итоги долгов. Обе суммы неотрицательные.
    struct Totals: Equatable {
        /// Вам должны (сумма положительных долгов).
        let owedToMe: Decimal
        /// Вы должны (модуль суммы отрицательных долгов).
        let iOwe: Decimal

        /// Итог со знаком: вам должны − вы должны.
        var net: Decimal { owedToMe - iOwe }

        static let zero = Totals(owedToMe: 0, iOwe: 0)
    }

    /// Вклад операции в долг контрагента: отправил — `+сумма`, пришли — `−сумма`, не долг — 0.
    static func signedAmount(of entry: EntryModel) -> Decimal {
        switch entry.debtDirection {
        case .sent: return entry.amount
        case .received: return -entry.amount
        case nil: return 0
        }
    }

    /// Долг по каждому контрагенту, у которого есть операции.
    static func balances(entries: [EntryModel]) -> [UUID: Decimal] {
        var result: [UUID: Decimal] = [:]
        for entry in entries where entry.type == .debt {
            guard let id = entry.counterparty?.id else { continue }
            result[id, default: 0] += signedAmount(of: entry)
        }
        return result
    }

    /// Итоги по контрагентам. Удалённые (`isArchived`) не учитываются.
    static func totals(of counterparties: [CounterpartyModel], balances: [UUID: Decimal]) -> Totals {
        var owedToMe = Decimal(0)
        var iOwe = Decimal(0)
        for counterparty in counterparties where !counterparty.isArchived {
            let balance = balances[counterparty.id] ?? 0
            if balance > 0 { owedToMe += balance } else { iOwe -= balance }
        }
        return Totals(owedToMe: owedToMe, iOwe: iOwe)
    }
}
