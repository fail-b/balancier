import SwiftUI

/// Вкладка «Счета» (§4.5): «Всего на счетах», список счетов, «+ Добавить счёт», категории.
struct AccountsView: View {
    @Bindable var viewModel: AccountsViewModel
    @Binding var isScrolled: Bool
    /// Тап по счёту → Главная с фильтром по нему (обрабатывает `ContentView`).
    let onSelectAccount: (UUID) -> Void

    @State private var accountFormVM: AccountFormViewModel?
    /// Строка счёта, открытая свайпом; nil — ни одна.
    @State private var openSwipeRowId: UUID?

    @State private var showingAddCategory = false
    @State private var showingEditCategory = false
    @State private var addCategoryVM: CategoryFormViewModel?
    @State private var editCategoryVM: CategoryFormViewModel?
    /// Модальный экран «Контрагенты» (тап по карточке «Долги», §4.11).
    @State private var counterpartiesVM: CounterpartiesViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    totalCard
                    if !viewModel.accounts.isEmpty {
                        accountsCard
                    }
                    addButton("Add Account") {
                        viewModel.dismissUndo()
                        accountFormVM = viewModel.makeAccountFormViewModel(for: nil)
                    }
                    Text("Tap an account to see its transactions on Home.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.ink2)
                        .padding(.horizontal, Theme.Spacing.xs)

                    debtsCard
                        .padding(.top, Theme.Spacing.s)

                    categoriesSection
                        .padding(.top, Theme.Spacing.xl)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(Theme.Colors.background)
            .clearsBottomAccessory()
            .reportsScroll(to: $isScrolled)
            // Скролл закрывает открытую свайпом строку (как в ленте Главной).
            .onScrollPhaseChange { _, newPhase in
                if newPhase == .interacting, openSwipeRowId != nil { openSwipeRowId = nil }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        AppIcon.image(named: AppIcon.settings)
                    }
                }
            }
            .sheet(item: $accountFormVM, onDismiss: { Task { await viewModel.load() } }) { vm in
                AccountFormView(viewModel: vm)
            }
            .sheet(item: $counterpartiesVM, onDismiss: { Task { await viewModel.load() } }) { vm in
                CounterpartiesView(viewModel: vm)
            }
            .sheet(isPresented: $showingAddCategory, onDismiss: { Task { await viewModel.load() } }) {
                if let vm = addCategoryVM { CategoryFormView(viewModel: vm) }
            }
            .sheet(isPresented: $showingEditCategory, onDismiss: { Task { await viewModel.load() } }) {
                if let vm = editCategoryVM { CategoryFormView(viewModel: vm) }
            }
            .task { await viewModel.load() }
            .overlay(alignment: .bottom) { undoToast }
            .animation(.snappy, value: viewModel.recentlyHidden?.id)
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Всего на счетах

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Total balance")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.ink2)
            Text(MoneyFormatter.balance(viewModel.totalBalance))
                .font(Theme.Font.heroAmount)
                .tracking(Theme.Font.Tracking.heroAmount)
                .foregroundStyle(Theme.Colors.ink)
                .lineLimit(1)
                .minimumScaleFactor(Theme.Size.summaryMinScale)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.hero))
    }

    // MARK: - Список счетов

    private var accountsCard: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.accounts) { account in
                // Свайп влево — «Скрыть» (длинный свайп скрывает сразу), тап — Главная с фильтром.
                // Фон строки (карточка) задаёт SwipeToDeleteRow — превью меню не прозрачное.
                SwipeToDeleteRow(
                    id: account.id,
                    openRowId: $openSwipeRowId,
                    content: { AccountRow(account: account, balance: viewModel.balance(for: account)) },
                    onTap: {
                        viewModel.dismissUndo()
                        onSelectAccount(account.id)
                    },
                    onDelete: { await viewModel.archive(account) },
                    actionTitle: String(localized: "Hide"),
                    actionIcon: AppIcon.archive
                )
                // Долгое нажатие → меню; можно не отпуская провести палец на пункт (§«Минимум тапов»).
                .contextMenu {
                    Button {
                        viewModel.dismissUndo()
                        accountFormVM = viewModel.makeAccountFormViewModel(for: account)
                    } label: {
                        Label { Text("Edit") } icon: { AppIcon.image(named: AppIcon.edit) }
                    }
                    Button(role: .destructive) {
                        Task { await viewModel.archive(account) }
                    } label: {
                        Label { Text("Hide") } icon: { AppIcon.image(named: AppIcon.archive) }
                    }
                }
                if account.id != viewModel.accounts.last?.id {
                    separator(inset: Theme.Accounts.separatorInset)
                }
            }
        }
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    // MARK: - Долги (§4.11)

    /// Карточка «Долги»: число контрагентов и итог со знаком. Полный список — в модальном экране.
    private var debtsCard: some View {
        let net = viewModel.debtTotals.net
        return Button {
            viewModel.dismissUndo()
            counterpartiesVM = viewModel.makeCounterpartiesViewModel()
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Circle()
                    .fill(Theme.Colors.fill)
                    .frame(width: Theme.Row.iconSize, height: Theme.Row.iconSize)
                    .overlay {
                        AppIcon.image(named: AppIcon.debts)
                            .font(Theme.Font.rowIcon)
                            .foregroundStyle(Theme.Colors.ink)
                    }
                VStack(alignment: .leading, spacing: Theme.Row.textSpacing) {
                    Text("Debts")
                        .font(Theme.Font.rowTitle)
                        .foregroundStyle(Theme.Colors.ink)
                    Text("Counterparties: \(viewModel.counterparties.count)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.ink2)
                }
                Spacer(minLength: Theme.Spacing.s)
                Text(MoneyFormatter.debt(net))
                    .font(Theme.Font.rowAmount)
                    .monospacedDigit()
                    .foregroundStyle(Theme.debtColor(for: net))
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Size.summaryMinScale)
                AppIcon.image(named: AppIcon.forward)
                    .font(Theme.Font.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.ink2)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }

    /// Плашка «Счёт/Категория … скрыт(а) · Отменить» — одна на экран, для последнего скрытия.
    @ViewBuilder
    private var undoToast: some View {
        if let hidden = viewModel.recentlyHidden {
            UndoToast(title: hidden.toastTitle) {
                Task { await viewModel.undoArchive() }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.s)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            // Новый id — новый отсчёт; уход с экрана отменяет таймер.
            .task(id: hidden.id) {
                guard (try? await Task.sleep(for: .seconds(Theme.Swipe.undoDuration))) != nil else { return }
                viewModel.dismissUndo()
            }
        }
    }

    // MARK: - Категории

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Categories")
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.Colors.ink)
                .padding(.leading, Theme.Spacing.xs)

            Picker("Type", selection: $viewModel.selectedCategoryType) {
                ForEach(CategoryType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if !viewModel.filteredCategories.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.filteredCategories) { category in
                        categoryRow(category)
                        if category.id != viewModel.filteredCategories.last?.id {
                            separator(inset: Theme.Row.separatorInset)
                        }
                    }
                }
                .background(Theme.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }

            addButton("Add Category") {
                viewModel.dismissUndo()
                addCategoryVM = viewModel.makeCategoryFormViewModel(for: nil)
                showingAddCategory = true
            }
        }
    }

    /// Строка категории: тап — изменить, свайп влево — «Скрыть» (с отменой), долгое нажатие — меню.
    private func categoryRow(_ category: CategoryModel) -> some View {
        SwipeToDeleteRow(
            id: category.id,
            openRowId: $openSwipeRowId,
            content: {
                HStack(spacing: Theme.Spacing.m) {
                    CategoryIcon(category: category, size: Theme.Row.iconSize)
                    Text(category.name)
                        .font(Theme.Font.rowTitle)
                        .foregroundStyle(Theme.Colors.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Row.verticalPadding)
            },
            onTap: { editCategory(category) },
            onDelete: { await viewModel.archive(category) },
            actionTitle: String(localized: "Hide"),
            actionIcon: AppIcon.archive
        )
        .contextMenu {
            Button {
                editCategory(category)
            } label: {
                Label { Text("Edit") } icon: { AppIcon.image(named: AppIcon.edit) }
            }
            Button(role: .destructive) {
                Task { await viewModel.archive(category) }
            } label: {
                Label { Text("Hide") } icon: { AppIcon.image(named: AppIcon.archive) }
            }
        }
    }

    private func editCategory(_ category: CategoryModel) {
        viewModel.dismissUndo()
        editCategoryVM = viewModel.makeCategoryFormViewModel(for: category)
        showingEditCategory = true
    }

    // MARK: - Общие элементы

    /// Кнопка-карточка «+ Добавить …» (`accent`).
    private func addButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                AppIcon.image(named: AppIcon.add)
                Text(title)
            }
            .font(Theme.Font.actionButton)
            .foregroundStyle(Theme.Colors.accent)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Accounts.addButtonHeight)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }

    private func separator(inset: CGFloat) -> some View {
        Rectangle()
            .fill(Theme.Colors.separator)
            .frame(height: Theme.Size.hairline)
            .padding(.leading, inset)
    }
}
