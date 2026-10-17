import Foundation

@Observable
final class AddEntryViewModel: Identifiable {
    let id = UUID()
    private(set) var accounts: [AccountModel] = []
    private(set) var categories: [CategoryModel] = []
    private(set) var balances: [UUID: Decimal] = [:]

    var selectedType = EntryType.expense
    /// Ввод суммы с цифровой клавиатуры (правила — в `AmountInput`).
    private(set) var amountInput = AmountInput()
    var selectedAccount: AccountModel?
    var selectedToAccount: AccountModel?
    var selectedCategory: CategoryModel?
    var note = ""
    var date = Date()
    var errorMessage: String?

    private let editingEntry: EntryModel?
    private var hasLoaded = false
    private let accountRepo: any AccountRepository
    private let categoryRepo: any CategoryRepository
    private let entryRepo: any EntryRepository
    private let tagRepo: any TagRepository
    private let counterpartyRepo: any CounterpartyRepository
    /// Тип и контрагент новой операции, если шит открыт с Главной при фильтре «Долги» (§4.11).
    private let initialType: EntryType?
    private let initialCounterpartyId: UUID?

    /// Локаль разделителей в поле суммы и сумм в подписях счетов (DI: в тестах — явная).
    private let locale: Locale

    init(entry: EntryModel? = nil, accountRepo: any AccountRepository, categoryRepo: any CategoryRepository, entryRepo: any EntryRepository,
         tagRepo: any TagRepository, counterpartyRepo: any CounterpartyRepository,
         initialType: EntryType? = nil, initialCounterpartyId: UUID? = nil, locale: Locale = .current) {
        self.locale = locale
        self.counterpartyRepo = counterpartyRepo
        self.initialType = initialType
        self.initialCounterpartyId = initialCounterpartyId
        self.editingEntry = entry
        self.accountRepo = accountRepo
        self.categoryRepo = categoryRepo
        self.entryRepo = entryRepo
        self.tagRepo = tagRepo
    }

    var isEditing: Bool { editingEntry != nil }

    /// Последняя допустимая дата операции — сегодня: операции из будущего пока запрещены
    /// (иначе в выборе месяца на Главной понадобились бы будущие месяцы).
    var latestAllowedDate: Date { Date() }

    /// Дата позже сегодняшнего дня.
    private func isInFuture(_ date: Date, now: Date) -> Bool {
        let cal = Calendar.current
        return cal.startOfDay(for: date) > cal.startOfDay(for: now)
    }
    var amount: Decimal { amountInput.value }

    /// Сумма строкой вида «1234.5» — для тестов и предзаполнения.
    var amountString: String {
        get { amountInput.text }
        set { amountInput.text = newValue }
    }

    /// Валюта операции = валюта выбранного счёта (символ «₽»/«$»/… зависит от неё).
    var currency: String { selectedAccount?.currency ?? "RUB" }
    var currencySymbol: String { MoneyFormatter.symbol(for: currency) }

    var filteredCategories: [CategoryModel] {
        categories.filter { $0.categoryType == selectedType.categoryType }
    }

    var canSave: Bool {
        guard amount > 0 else { return false }
        switch selectedType {
        case .expense, .income: return selectedAccount != nil && selectedCategory != nil
        case .transfer: return selectedAccount != nil && selectedToAccount != nil && selectedAccount?.id != selectedToAccount?.id
        case .debt: return selectedAccount != nil && selectedCounterparty != nil
        }
    }

    func balance(for account: AccountModel) -> Decimal {
        balances[account.id] ?? account.initialBalance
    }

    /// Подпись строки счёта: «Тинькофф · 154 320 ₽».
    func subtitle(for account: AccountModel) -> String {
        "\(account.name) · \(MoneyFormatter.format(balance(for: account), currency: account.currency, locale: locale))"
    }

    func load() async {
        do {
            async let accs = accountRepo.fetchAll()
            async let cats = categoryRepo.fetchAll()
            async let ents = entryRepo.fetchAll()
            async let tgs = tagRepo.fetchAll()
            async let cps = counterpartyRepo.fetchAll()
            let (fetchedAccounts, fetchedCategories, fetchedEntries, fetchedTags, fetchedCounterparties)
                = try await (accs, cats, ents, tgs, cps)
            allCounterparties = fetchedCounterparties
            // Подсказка — долг без учёта редактируемой операции.
            debtBalances = DebtService.balances(entries: fetchedEntries.filter { $0.id != editingEntry?.id })
            accounts = fetchedAccounts
            categories = fetchedCategories
            entries = fetchedEntries
            allTags = fetchedTags
            // Операцию со скрытым счётом/категорией тоже можно отредактировать: подставляем их
            // в списки выбора (только для этой операции), иначе выбор пустой и «Сохранить» неактивна.
            if let entry = editingEntry {
                for account in [entry.fromAccount, entry.toAccount].compactMap({ $0 })
                where !accounts.contains(where: { $0.id == account.id }) {
                    accounts.append(account)
                }
                if let category = entry.category, !categories.contains(where: { $0.id == category.id }) {
                    categories.append(category)
                }
            }
            balances = BalanceService.computeBalances(accounts: accounts, entries: fetchedEntries)

            if !hasLoaded {
                hasLoaded = true
                if let entry = editingEntry {
                    selectedType = entry.type
                    amountInput = AmountInput(decimal: entry.amount)
                    date = entry.date
                    note = entry.note ?? ""
                    switch entry.type {
                    case .expense:
                        selectedAccount = entry.fromAccount.flatMap { a in accounts.first { $0.id == a.id } }
                    case .income:
                        selectedAccount = entry.toAccount.flatMap { a in accounts.first { $0.id == a.id } }
                    case .transfer:
                        selectedAccount = entry.fromAccount.flatMap { a in accounts.first { $0.id == a.id } }
                        selectedToAccount = entry.toAccount.flatMap { a in accounts.first { $0.id == a.id } }
                    case .debt:
                        debtDirection = entry.debtDirection ?? .sent
                        selectedAccount = (entry.fromAccount ?? entry.toAccount).flatMap { a in accounts.first { $0.id == a.id } }
                        // Удалённого контрагента тоже подставляем — иначе «Сохранить» неактивна.
                        if let cp = entry.counterparty, !allCounterparties.contains(where: { $0.id == cp.id }) {
                            allCounterparties.append(cp)
                        }
                        selectedCounterparty = entry.counterparty.flatMap { c in allCounterparties.first { $0.id == c.id } }
                    }
                    selectedCategory = entry.category.flatMap { c in categories.first { $0.id == c.id } }
                    for tag in entry.tags where !allTags.contains(where: { $0.id == tag.id }) {
                        allTags.append(tag)
                    }
                    selectedTags = entry.tags.compactMap { t in allTags.first { $0.id == t.id } }
                } else {
                    selectedAccount = accounts.first
                    if let initialType { selectedType = initialType }
                    if let id = initialCounterpartyId {
                        selectedCounterparty = allCounterparties.first { $0.id == id && !$0.isArchived }
                    }
                    onTypeChanged()
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Смена типа и дефолты

    /// Вызывается при смене сегмента Расход/Доход/Перевод.
    func onTypeChanged() {
        if selectedType == .debt {
            // У долга нет категории и тегов (§4.11).
            selectedCategory = nil
            selectedTags = []
            cancelAddingTag()
        } else if selectedType == .transfer {
            selectedCategory = nil
            // У перевода тегов нет.
            selectedTags = []
            cancelAddingTag()
            if selectedToAccount == nil || selectedToAccount?.id == selectedAccount?.id {
                selectedToAccount = accounts.first { $0.id != selectedAccount?.id }
            }
        } else {
            if selectedCategory == nil || selectedCategory?.categoryType != selectedType.categoryType {
                selectedCategory = filteredCategories.first
            }
        }
    }

    // MARK: - Теги (§4.7)

    /// Все теги из хранилища, включая скрытые: по ним новый тег с тем же именем возвращает скрытый.
    private(set) var allTags: [TagModel] = []
    /// Операции — для порядка карусели тегов по частоте.
    private var entries: [EntryModel] = []
    /// Теги операции. В шите ставится один; два — только у импортированной операции при редактировании.
    private(set) var selectedTags: [TagModel] = []
    /// Ячейка «+» карусели превращена в поле ввода нового тега.
    private(set) var isAddingTag = false
    var newTagName = ""
    /// Тег, который переименовывают (алерт с полем), и новое имя.
    private(set) var tagBeingRenamed: TagModel?
    var renameText = ""

    /// Карусель тегов есть у расхода и дохода; у перевода тегов нет.
    var showsTags: Bool { selectedType == .expense || selectedType == .income }

    /// Карусель: видимые теги и выбранные (даже скрытые — чтобы их можно было снять),
    /// первыми — чаще использованные с выбранной категорией.
    var carouselTags: [TagModel] {
        let visible = allTags.filter { !$0.isArchived || isSelected($0) }
        return TagUsageService.ordered(visible, entries: entries, category: selectedCategory)
    }

    func isSelected(_ tag: TagModel) -> Bool {
        selectedTags.contains { $0.id == tag.id }
    }

    /// Тап по тегу: выбранный — снять, иначе выбрать вместо текущих (у операции из шита один тег).
    func toggleTag(_ tag: TagModel) {
        if isSelected(tag) {
            selectedTags.removeAll { $0.id == tag.id }
        } else {
            selectedTags = [tag]
        }
    }

    /// Тап по «+» в карусели.
    func startAddingTag() {
        newTagName = ""
        isAddingTag = true
    }

    func cancelAddingTag() {
        isAddingTag = false
        newTagName = ""
    }

    /// «Готово» в поле нового тега: тег создаётся и выбирается. Если тег с таким именем уже есть
    /// (без учёта регистра), выбирается он, а скрытый возвращается — дубль не создаётся.
    /// Пустое имя просто закрывает поле.
    func commitNewTag() async {
        let name = TagUsageService.cleanName(newTagName)
        cancelAddingTag()
        guard !name.isEmpty else { return }
        if var existing = allTags.first(where: { TagUsageService.sameName($0.name, name, locale: locale) }) {
            if existing.isArchived {
                existing.isArchived = false
                existing.updatedAt = Date()
                do { try await tagRepo.save(existing) } catch { errorMessage = error.localizedDescription; return }
                replaceLocal(existing)
            }
            selectedTags = [existing]
            return
        }
        let now = Date()
        let tag = TagModel(id: UUID(), name: name, isArchived: false, createdAt: now, updatedAt: now)
        do { try await tagRepo.save(tag) } catch { errorMessage = error.localizedDescription; return }
        allTags.append(tag)
        selectedTags = [tag]
    }

    /// «Переименовать» в меню тега (долгий тап).
    func beginRename(_ tag: TagModel) {
        tagBeingRenamed = tag
        renameText = tag.name
    }

    func cancelRename() {
        tagBeingRenamed = nil
        renameText = ""
    }

    /// «Сохранить» в алерте: переименовать тег, который сейчас редактируется.
    func commitRename() async {
        guard let tag = tagBeingRenamed else { return }
        let name = renameText
        cancelRename()
        await rename(tag, to: name)
    }

    /// Новое имя меняется у самого тега — значит, и на всех операциях с ним.
    /// Имя, занятое другим тегом (в т.ч. скрытым), — ошибка.
    func rename(_ tag: TagModel, to newName: String) async {
        cancelRename()
        var tag = tag
        let name = TagUsageService.cleanName(newName)
        guard !name.isEmpty, name != tag.name else { return }
        if allTags.contains(where: { $0.id != tag.id && TagUsageService.sameName($0.name, name, locale: locale) }) {
            errorMessage = String(localized: "A tag with this name already exists.")
            return
        }
        tag.name = name
        tag.updatedAt = Date()
        do { try await tagRepo.save(tag) } catch { errorMessage = error.localizedDescription; return }
        replaceLocal(tag)
    }

    /// «Скрыть» в меню тега: тег пропадает из карусели и снимается с этой операции;
    /// на сохранённых операциях остаётся.
    func hideTag(_ tag: TagModel) async {
        do { try await tagRepo.archive(tag.id) } catch { errorMessage = error.localizedDescription; return }
        selectedTags.removeAll { $0.id == tag.id }
        var hidden = tag
        hidden.isArchived = true
        replaceLocal(hidden)
    }

    private func replaceLocal(_ tag: TagModel) {
        if let i = allTags.firstIndex(where: { $0.id == tag.id }) { allTags[i] = tag } else { allTags.append(tag) }
        if let i = selectedTags.firstIndex(where: { $0.id == tag.id }) { selectedTags[i] = tag }
    }

    // MARK: - Долг (§4.11)

    /// «Я отправил» / «Мне пришли».
    var debtDirection = DebtDirection.sent
    /// Все контрагенты, включая удалённых: по ним новый с тем же именем возвращает удалённого.
    private(set) var allCounterparties: [CounterpartyModel] = []
    var selectedCounterparty: CounterpartyModel?
    /// Долги по контрагентам — для подсказки под каруселью.
    private var debtBalances: [UUID: Decimal] = [:]
    /// Ячейка «+» карусели контрагентов превращена в поле ввода.
    private(set) var isAddingCounterparty = false
    var newCounterpartyName = ""

    /// Карусель: не удалённые контрагенты и выбранный (даже удалённый — при редактировании).
    var carouselCounterparties: [CounterpartyModel] {
        allCounterparties.filter { !$0.isArchived || $0.id == selectedCounterparty?.id }
    }

    /// Текущий долг выбранного контрагента (без учёта этой операции); nil — контрагент не выбран.
    var selectedCounterpartyDebt: Decimal? {
        guard let id = selectedCounterparty?.id else { return nil }
        return debtBalances[id] ?? 0
    }

    /// Подсказка под каруселью: «Мне должны +500 ₽» / «Я должен −177 219 ₽» / «Долга нет».
    var counterpartyHint: String? {
        guard let debt = selectedCounterpartyDebt else { return nil }
        let amount = MoneyFormatter.debt(debt, currency: currency, locale: locale)
        if debt > 0 { return String(localized: "Owed to me \(amount)") }
        if debt < 0 { return String(localized: "I owe \(amount)") }
        return String(localized: "No debt")
    }

    /// Тап по контрагенту: выбрать (повторный тап не снимает — без контрагента долг не сохранить).
    func selectCounterparty(_ counterparty: CounterpartyModel) {
        selectedCounterparty = counterparty
    }

    func startAddingCounterparty() {
        newCounterpartyName = ""
        isAddingCounterparty = true
    }

    func cancelAddingCounterparty() {
        isAddingCounterparty = false
        newCounterpartyName = ""
    }

    /// «Готово» в поле нового контрагента: создаётся и выбирается. Имя уже есть (без учёта регистра) —
    /// выбирается существующий, удалённый возвращается. Пустое имя просто закрывает поле.
    func commitNewCounterparty() async {
        let name = TagUsageService.cleanName(newCounterpartyName)
        cancelAddingCounterparty()
        guard !name.isEmpty else { return }
        if var existing = allCounterparties.first(where: { TagUsageService.sameName($0.name, name, locale: locale) }) {
            if existing.isArchived {
                existing.isArchived = false
                existing.updatedAt = Date()
                do { try await counterpartyRepo.save(existing) } catch { errorMessage = error.localizedDescription; return }
                if let i = allCounterparties.firstIndex(where: { $0.id == existing.id }) { allCounterparties[i] = existing }
            }
            selectedCounterparty = existing
            return
        }
        let counterparty = CounterpartyModel.new(name: name, existing: allCounterparties)
        do { try await counterpartyRepo.save(counterparty) } catch { errorMessage = error.localizedDescription; return }
        allCounterparties.append(counterparty)
        selectedCounterparty = counterparty
    }

    // MARK: - Ввод суммы (правила §4.7 — в AmountInput)

    func press(_ key: NumpadKey) {
        amountInput.apply(key)
    }

    /// Сумма для показа: «1 234,5».
    var formattedAmount: String { amountInput.formatted(locale: locale) }

    func save() async {
        // Новый тег введён, но «Готово» не нажата — сохраняем и ставим его (минимум тапов).
        if isAddingTag {
            await commitNewTag()
            if errorMessage != nil { return }
        }
        if isAddingCounterparty {
            await commitNewCounterparty()
            if errorMessage != nil { return }
        }
        let now = Date()
        guard !isInFuture(date, now: now) else {
            errorMessage = String(localized: "The transaction date can’t be later than today.")
            return
        }
        var entry = EntryModel(
            id: editingEntry?.id ?? UUID(),
            date: date,
            type: selectedType,
            amount: amount,
            currency: currency,
            note: note.isEmpty ? nil : note,
            tags: showsTags ? selectedTags : [],
            isRecurring: editingEntry?.isRecurring ?? false,
            isSoftDeleted: false,
            createdAt: editingEntry?.createdAt ?? now,
            updatedAt: now,
            fromAccount: nil,
            toAccount: nil,
            category: nil
        )
        let from: AccountModel?
        let to: AccountModel?
        switch selectedType {
        case .expense:
            from = selectedAccount
            to = nil
        case .income:
            from = nil
            to = selectedAccount
        case .transfer:
            from = selectedAccount
            to = selectedToAccount
        case .debt:
            // Отправил — деньги ушли со счёта, пришли — на счёт (§4.11).
            from = debtDirection == .sent ? selectedAccount : nil
            to = debtDirection == .received ? selectedAccount : nil
        }
        let cat: CategoryModel? = selectedType == .expense || selectedType == .income ? selectedCategory : nil
        entry.counterparty = selectedType == .debt ? selectedCounterparty : nil
        do { try await entryRepo.save(entry, fromAccount: from, toAccount: to, category: cat) } catch { errorMessage = error.localizedDescription }
    }
}

private extension EntryType {
    var categoryType: CategoryType {
        switch self {
        case .expense: return .expense
        case .income: return .income
        case .transfer, .debt: return .expense
        }
    }
}
