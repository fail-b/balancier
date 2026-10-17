import Foundation

/// Что скрыто последним — для плашки «Отменить» на вкладке «Счета» (§4.5).
/// Отменить можно только последнее скрытие: новое скрытие заменяет плашку.
enum HiddenItem: Equatable {
    case account(AccountModel)
    case category(CategoryModel)

    var id: UUID {
        switch self {
        case .account(let account): return account.id
        case .category(let category): return category.id
        }
    }

    var toastTitle: String {
        switch self {
        case .account(let account): return String(localized: "Account “\(account.name)” hidden")
        case .category(let category): return String(localized: "Category “\(category.name)” hidden")
        }
    }
}

@Observable
final class AccountsViewModel: Identifiable {
    let id = UUID()
    private(set) var accounts: [AccountModel] = []
    private(set) var categories: [CategoryModel] = []
    private(set) var balances: [UUID: Decimal] = [:]
    var selectedCategoryType = CategoryType.expense
    var errorMessage: String?
    /// Последнее скрытое (счёт или категория) — пока видна плашка «… скрыт · Отменить».
    private(set) var recentlyHidden: HiddenItem?

    private let accountRepo: any AccountRepository
    private let categoryRepo: any CategoryRepository
    private let entryRepo: any EntryRepository
    private let counterpartyRepo: any CounterpartyRepository

    /// Контрагенты (без удалённых) и их долги — для карточки «Долги» (§4.11).
    private(set) var counterparties: [CounterpartyModel] = []
    private var debtBalances: [UUID: Decimal] = [:]

    init(accountRepo: any AccountRepository, categoryRepo: any CategoryRepository, entryRepo: any EntryRepository,
         counterpartyRepo: any CounterpartyRepository) {
        self.counterpartyRepo = counterpartyRepo
        self.accountRepo = accountRepo
        self.categoryRepo = categoryRepo
        self.entryRepo = entryRepo
    }

    var filteredCategories: [CategoryModel] {
        categories.filter { $0.categoryType == selectedCategoryType }
    }

    /// «Всего на счетах».
    var totalBalance: Decimal {
        BalanceService.total(of: accounts, balances: balances)
    }

    func balance(for account: AccountModel) -> Decimal {
        balances[account.id] ?? account.initialBalance
    }

    /// Итоги долгов для карточки «Долги».
    var debtTotals: DebtService.Totals {
        DebtService.totals(of: counterparties, balances: debtBalances)
    }

    func load() async {
        do {
            async let a = accountRepo.fetchAll()
            async let c = categoryRepo.fetchAll()
            async let e = entryRepo.fetchAll()
            async let p = counterpartyRepo.fetchAll()
            let (accs, cats, entries, cps) = try await (a, c, e, p)
            accounts = accs
            categories = cats
            balances = BalanceService.computeBalances(accounts: accs, entries: entries)
            counterparties = cps.filter { !$0.isArchived }
            debtBalances = DebtService.balances(entries: entries)
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Скрытие с отменой (счета и категории)

    /// Скрывает счёт. `false` — не удалось (строка со свайпом возвращается, прежняя плашка остаётся).
    @discardableResult
    func archive(_ account: AccountModel) async -> Bool {
        do {
            try await accountRepo.archive(account.id)
            accounts.removeAll { $0.id == account.id }
            recentlyHidden = .account(account)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Скрывает категорию. Операции с ней остаются (в ленте и статистике она видна по-прежнему).
    @discardableResult
    func archive(_ category: CategoryModel) async -> Bool {
        do {
            try await categoryRepo.archive(category.id)
            categories.removeAll { $0.id == category.id }
            recentlyHidden = .category(category)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// «Отменить» на плашке: возвращает последнее скрытое. Повторный вызов ничего не делает.
    func undoArchive() async {
        guard let item = recentlyHidden else { return }
        recentlyHidden = nil
        do {
            switch item {
            case .account(let account):
                try await accountRepo.unarchive(account.id)
            case .category(let category):
                try await categoryRepo.unarchive(category.id)
                // Вернувшаяся категория должна быть видна — переключаем сегмент на её тип.
                selectedCategoryType = category.categoryType
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await load()
    }

    /// Плашка отмены скрыта (истекло время или начато другое действие).
    func dismissUndo() {
        recentlyHidden = nil
    }

    func makeAccountFormViewModel(for account: AccountModel?) -> AccountFormViewModel {
        AccountFormViewModel(account: account, accountRepo: accountRepo)
    }

    /// Модальный экран «Контрагенты» (тап по карточке «Долги»).
    func makeCounterpartiesViewModel() -> CounterpartiesViewModel {
        CounterpartiesViewModel(counterpartyRepo: counterpartyRepo, entryRepo: entryRepo)
    }

    func makeCategoryFormViewModel(for category: CategoryModel?) -> CategoryFormViewModel {
        CategoryFormViewModel(category: category, categoryRepo: categoryRepo)
    }
}
