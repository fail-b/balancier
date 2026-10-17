import Foundation

/// Модальный экран «Контрагенты» (§4.11): список с долгами, добавление, изменение, удаление.
@Observable
final class CounterpartiesViewModel: Identifiable {
    let id = UUID()
    /// Контрагенты без удалённых, по порядку.
    private(set) var counterparties: [CounterpartyModel] = []
    private var allCounterparties: [CounterpartyModel] = []
    private var debtBalances: [UUID: Decimal] = [:]
    /// Контрагент с ненулевым долгом, удаление которого ждёт подтверждения (alert).
    private(set) var pendingDeletion: CounterpartyModel?
    var errorMessage: String?

    private let counterpartyRepo: any CounterpartyRepository
    private let entryRepo: any EntryRepository
    private let locale: Locale

    init(counterpartyRepo: any CounterpartyRepository, entryRepo: any EntryRepository, locale: Locale = .current) {
        self.counterpartyRepo = counterpartyRepo
        self.entryRepo = entryRepo
        self.locale = locale
    }

    var totals: DebtService.Totals {
        DebtService.totals(of: counterparties, balances: debtBalances)
    }

    func debt(for counterparty: CounterpartyModel) -> Decimal {
        debtBalances[counterparty.id] ?? 0
    }

    func load() async {
        do {
            async let p = counterpartyRepo.fetchAll()
            async let e = entryRepo.fetchAll()
            let (cps, entries) = try await (p, e)
            allCounterparties = cps
            counterparties = cps.filter { !$0.isArchived }
            debtBalances = DebtService.balances(entries: entries)
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Удаление (мягкое)

    /// Свайп «Удалить» / пункт меню. Долг 0 — удаляет сразу (`true`); иначе ждёт подтверждения
    /// (`pendingDeletion`) и возвращает `false` — строка возвращается на место.
    @discardableResult
    func requestDelete(_ counterparty: CounterpartyModel) async -> Bool {
        guard debt(for: counterparty) == 0 else {
            pendingDeletion = counterparty
            return false
        }
        return await delete(counterparty)
    }

    /// Текст подтверждения: «Долг +500 ₽ останется в истории операций, но пропадёт из итогов.»
    var pendingDeletionMessage: String {
        guard let counterparty = pendingDeletion else { return "" }
        let amount = MoneyFormatter.debt(debt(for: counterparty), locale: locale)
        return String(localized: "The debt of \(amount) will stay in the transaction history but will no longer count in totals.")
    }

    func confirmDelete() async {
        guard let counterparty = pendingDeletion else { return }
        pendingDeletion = nil
        await delete(counterparty)
    }

    func cancelDelete() {
        pendingDeletion = nil
    }

    @discardableResult
    private func delete(_ counterparty: CounterpartyModel) async -> Bool {
        do {
            try await counterpartyRepo.archive(counterparty.id)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        counterparties.removeAll { $0.id == counterparty.id }
        if let i = allCounterparties.firstIndex(where: { $0.id == counterparty.id }) { allCounterparties[i].isArchived = true }
        return true
    }

    func makeFormViewModel(for counterparty: CounterpartyModel?) -> CounterpartyFormViewModel {
        CounterpartyFormViewModel(counterparty: counterparty, counterpartyRepo: counterpartyRepo, locale: locale)
    }
}
