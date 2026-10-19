import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var selectedTab: AppTab
    @Binding var isScrolled: Bool

    // Настройки открываются переходом вглубь (push), не шитом (§4.8).
    @State private var showingSettings = false
    @State private var editEntryVM: AddEntryViewModel?
    // Строка ленты, открытая свайпом (кнопка «Удалить»): одна на всю ленту, скролл её закрывает.
    @State private var openSwipeRowId: UUID?

    // Жест «потянуть вниз» → поиск (§4.1.4) — только на геометрии и фазе скролла, без DragGesture
    // (DragGesture поверх ScrollView ломал прокрутку). overscroll — оттяжка за верхний край.
    @State private var overscroll: CGFloat = 0
    @State private var isInteracting = false
    @State private var reachedThreshold = false
    // Закрытие поиска: контент короче экрана (можно ли по нему скроллить).
    @State private var isScrollable = false
    // Фокус строки поиска живёт здесь, чтобы закрытие могло снять его явно (скрыть клавиатуру).
    @FocusState private var isSearchFocused: Bool
    // Закрытие поиска свайпом откладывается до остановки скролла: менять раскладку
    // (вставлять hero, убирать пустую зону) под пальцем — это и давало рывок.
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var pendingClose = false
    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// Главная на экране (вкладка выбрана). Пока скрыта — к счёту не прокручиваем: скрытый скролл не двигается.
    @State private var isVisible = false
    // Высота hero вместе с верхним отступом — последняя измеренная (в поиске hero нет в раскладке).
    @State private var heroHeight: CGFloat = 0
    // Высота шапки (строка поиска с отступами): по ней решаем, видна ли строка при закрытии.
    @State private var headerHeight: CGFloat = 0
    // Текущее смещение ленты. Класс без наблюдения: запись не перерисовывает экран на каждом кадре.
    @State private var scrollMetrics = ScrollMetrics()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Прогресс жеста 0…1; в режиме поиска жест выключен.
    private var pullProgress: CGFloat {
        guard !viewModel.isSearchActive else { return 0 }
        return min(overscroll / Theme.Pull.threshold, 1)
    }

    var body: some View {
        // proxy уже учитывает клавиатуру: в поиске лента тянется ровно до неё.
        GeometryReader { proxy in
            feed(minHeight: proxy.size.height)
        }
        .background(Theme.Colors.background)
        // Своя шапка вместо навбара; стек нужен только для перехода в Настройки.
        .toolbarVisibility(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showingSettings) {
            SettingsView()
        }
        // В Настройках нет ленты — прячем сводку у таб-бара, пока экран открыт.
        .onChange(of: showingSettings) { _, isShown in
            if isShown { isScrolled = false }
        }
        .sheet(item: $editEntryVM, onDismiss: { Task { await viewModel.load() } }) { vm in
            AddEntryView(viewModel: vm)
        }
        .task { await viewModel.load() }
        // Переход со вкладки «Счета»: лента — в начало, карусель — к выбранному счёту.
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: viewModel.isSearchActive) { _, isActive in
            if !isActive { isSearchFocused = false }
        }
        .overlay(alignment: .bottom) { undoToast }
        .animation(.snappy, value: viewModel.recentlyDeleted?.id)
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Отмена удаления

    /// Плашка «Операция удалена · Отменить» после удаления свайпом (§4.2).
    @ViewBuilder
    private var undoToast: some View {
        if let deleted = viewModel.recentlyDeleted {
            UndoToast(title: String(localized: "Transaction deleted")) {
                Task { await viewModel.undoDelete() }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.s)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            // Новый id — новый отсчёт; уход с экрана отменяет таймер.
            .task(id: deleted.id) {
                guard (try? await Task.sleep(for: .seconds(Theme.Swipe.undoDuration))) != nil else { return }
                viewModel.dismissUndo()
            }
        }
    }

    // MARK: - Лента

    /// Скролл Главной с жестами поиска: «потянуть вниз» — открыть, свайп вверх — закрыть.
    private func feed(minHeight: CGFloat) -> some View {
        ScrollView {
            feedContent(minHeight: minHeight)
        }
        // В поиске короткий контент не отскакивает (иначе свайп вверх «дёргает» экран).
        // Вне поиска отскок нужен всегда — на нём держится «потянуть вниз».
        .scrollBounceBehavior(viewModel.isSearchActive ? .basedOnSize : .always)
        .scrollDismissesKeyboard(.immediately)
        .clearsBottomAccessory()
        .reportsScroll(to: $isScrolled)
        .reportsOverscroll(to: $overscroll)
        .reportsScrollable(to: $isScrollable)
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scrollMetrics.offset = offset
        }
        // Верхний inset (статус-бар): лента рисуется и под ним, строка там тоже видна.
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentInsets.top
        } action: { _, inset in
            scrollMetrics.topInset = inset
        }
        .onChange(of: isSearchFocused) { _, focused in
            handleSearchFocusChange(focused)
        }
        .onChange(of: viewModel.searchQuery) { _, _ in
            if !searchQueryEmpty { pendingClose = false }
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            handleScrollPhase(from: oldPhase, to: newPhase)
        }
        .onChange(of: overscroll) { _, value in
            // Порог считаем, только пока палец на экране (не во время отскока назад).
            guard isInteracting, !viewModel.isSearchActive else { return }
            reachedThreshold = value >= Theme.Pull.threshold
        }
        .sensoryFeedback(trigger: reachedThreshold) { _, reached in
            reached ? .impact(weight: .medium) : nil
        }
    }

    /// Контент ленты + пустая зона под ней (только в поиске), тап по которой закрывает поиск.
    private func feedContent(minHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            feedItems
                .padding(.bottom, Theme.Spacing.s)

            // Шапка, счета и операции — выше и в эту зону не входят.
            if viewModel.isSearchActive {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { closeSearch() }
            }
        }
        // В поиске контент не ниже видимой области — пустая зона растягивается до клавиатуры.
        .frame(minHeight: viewModel.isSearchActive ? minHeight : 0, alignment: .top)
        .contentShape(Rectangle())
        // Свайп вверх закрывает поиск, если контент короче экрана. Жест включён только тогда:
        // в остальное время на ленте нет ни одного DragGesture, скролл работает нативно.
        .simultaneousGesture(
            swipeUpToClose,
            including: viewModel.isSearchActive && !isScrollable ? .all : .subviews
        )
    }

    private var feedItems: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeHeader(
                viewModel: viewModel,
                pullProgress: pullProgress,
                searchFocus: $isSearchFocused,
                onOpenSettings: { showingSettings = true }
            )
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }

            if !viewModel.isSearchActive {
                heroCard
                    .padding(.top, Theme.Spacing.s)
                    .padding(.horizontal, Theme.Spacing.l)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heroHeight = $0 }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            accountFilterChips
                .padding(.top, Theme.Spacing.xl)

            if viewModel.isDebtFilterActive {
                counterpartyChips
                    .padding(.top, Theme.Spacing.s)
                    .transition(.opacity)
            }

            if viewModel.entriesByDay.isEmpty {
                emptyStateView
            } else {
                // Lazy (долг №15): строки создаются по мере прокрутки, а не все тысячи сразу.
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.entriesByDay) { group in
                        DaySection(
                            group: group,
                            openRowId: $openSwipeRowId,
                            onTap: { entry in
                                editEntryVM = viewModel.makeAddEntryViewModel(for: entry)
                            },
                            onDelete: { entry in
                                await viewModel.delete(entry: entry)
                            },
                            onTagTap: { tag in searchByTag(tag) }
                        )
                        .padding(.top, Theme.Spacing.xl)
                        .padding(.horizontal, Theme.Spacing.l)
                    }
                }
            }
        }
    }

    private var swipeUpToClose: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard viewModel.isSearchActive, !isScrollable else { return }
                let dy = value.translation.height
                guard dy < -Theme.Pull.threshold, abs(dy) > abs(value.translation.width) else { return }
                closeSearch()
            }
    }

    /// Жест «потянуть вниз» → поиск (§4.1.4): палец отпущен (выход из `.interacting`)
    /// при оттяжке за порог — активируем поиск; иначе лента сама отскакивает назад.
    private func handleScrollPhase(from oldPhase: ScrollPhase, to newPhase: ScrollPhase) {
        scrollPhase = newPhase
        isInteracting = newPhase == .interacting
        // Вертикальный скролл закрывает открытую свайпом строку (как в списках iOS).
        if newPhase == .interacting, openSwipeRowId != nil { openSwipeRowId = nil }
        if newPhase == .idle, pendingClose {
            pendingClose = false
            // Не внутри обработчика скролла: после отскока у края SwiftUI применяет изменения
            // из этого колбэка без анимации. На следующем такте withAnimation срабатывает.
            DispatchQueue.main.async {
                guard scrollPhase == .idle else {
                    pendingClose = true
                    return
                }
                closeSearchKeepingPosition()
            }
        }
        guard oldPhase == .interacting, newPhase != .interacting else { return }
        let shouldActivate = reachedThreshold && !viewModel.isSearchActive
        reachedThreshold = false
        if shouldActivate { activateSearchFromGesture() }
    }

    // MARK: - Hero Card

    @ViewBuilder
    private var heroCard: some View {
        if viewModel.isDebtFilterActive {
            debtHeroCard
        } else {
            expenseHeroCard
        }
    }

    /// Hero в режиме долгов (§4.11): «Вам должны» и «Вы должны» — по всем контрагентам или по выбранному.
    private var debtHeroCard: some View {
        let totals = viewModel.heroDebtTotals
        return HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: Theme.Row.textSpacing) {
                Text("Owed to you")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.ink2)
                Text(MoneyFormatter.format(totals.owedToMe))
                    .font(Theme.Font.heroAmount)
                    .tracking(Theme.Font.Tracking.heroAmount)
                    .foregroundStyle(Theme.Colors.debtOwedToMe)
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Size.summaryMinScale)
            }
            Spacer(minLength: Theme.Spacing.s)
            VStack(alignment: .trailing, spacing: Theme.Row.textSpacing) {
                Text("You owe")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.ink2)
                Text(MoneyFormatter.format(totals.iOwe))
                    .font(Theme.Font.headline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.debtIOwe)
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Size.summaryMinScale)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Hero.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.hero))
        .accessibilityElement(children: .combine)
    }

    private var expenseHeroCard: some View {
        Button {
            selectedTab = .statistics
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.heroExpenseTitle)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.ink2)
                        Text(MoneyFormatter.format(viewModel.heroExpense))
                            .font(Theme.Font.heroAmount)
                            .tracking(Theme.Font.Tracking.heroAmount)
                            .foregroundStyle(Theme.Colors.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(viewModel.heroIncomeTitle)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.ink2)
                        Text(verbatim: "+\(MoneyFormatter.format(viewModel.heroIncome))")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.Colors.income)
                    }
                }

                heroProgressBar

                if !viewModel.heroLegend.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(viewModel.heroLegend) { segment in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: segment.colorHex) ?? Theme.Colors.fallback)
                                    .frame(width: 7, height: 7)
                                Text(verbatim: "\(segment.name) \(segment.percent.formatted(.percent))")
                                    .font(Theme.Font.time)
                                    .foregroundStyle(Theme.Colors.ink2)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.hero))
        }
        .buttonStyle(.plain)
    }

    private var heroProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Theme.Colors.fill)

                HStack(spacing: 2) {
                    ForEach(viewModel.heroSegments) { segment in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(hex: segment.colorHex) ?? Theme.Colors.fallback)
                            .frame(width: geo.size.width * CGFloat(segment.fraction))
                            .animation(.easeOut(duration: 0.5), value: segment.fraction)
                    }
                }
            }
        }
        .frame(height: 10)
    }

    // MARK: - Account Filter Chips

    private var accountFilterChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) {
                    AccountChip(
                        title: String(localized: "All"),
                        colorHex: nil,
                        balance: viewModel.totalBalance,
                        isActive: viewModel.isAllSelected
                    ) {
                        withAnimation(.snappy) { viewModel.selectAll() }
                    }
                    ForEach(viewModel.accounts) { account in
                        AccountChip(
                            title: account.name,
                            colorHex: account.colorHex,
                            balance: viewModel.balances[account.id] ?? 0,
                            isActive: viewModel.selectedAccountId == account.id
                        ) {
                            withAnimation(.snappy) { viewModel.toggleAccount(account.id) }
                        }
                        .id(account.id)
                    }
                    // «Долги» — в конце карусели (§4.11): все долги, ниже — карусель контрагентов.
                    if viewModel.showsDebtsChip {
                        AccountChip(
                            title: String(localized: "Debts"),
                            colorHex: nil,
                            balance: viewModel.debtTotals.net,
                            isActive: viewModel.isDebtFilterActive,
                            isDebt: true
                        ) {
                            withAnimation(.snappy) { viewModel.toggleDebts() }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
            }
            // Переход со вкладки «Счета»: ждём, пока Главная видна и чип счёта уже есть
            // (новый счёт появляется после load()), затем — лента в начало, чип в центр.
            .task(id: pendingReveal) {
                guard let id = pendingReveal else { return }
                // Ждём, пока Главная после смены вкладки встанет на экран:
                // scrollTo в момент переключения теряется, и чип остаётся за краем.
                try? await Task.sleep(for: Theme.Animation.revealDelay)
                guard !Task.isCancelled else { return }
                scrollPosition.scrollTo(edge: .top)
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
                viewModel.didRevealAccount()
            }
        }
    }

    /// Вторая карусель — контрагенты с долгами (при фильтре «Долги», §4.11).
    private var counterpartyChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(viewModel.counterparties) { counterparty in
                    AccountChip(
                        title: counterparty.name,
                        colorHex: counterparty.colorHex,
                        balance: viewModel.debt(for: counterparty),
                        isActive: viewModel.selectedCounterpartyId == counterparty.id,
                        isDebt: true
                    ) {
                        withAnimation(.snappy) { viewModel.toggleCounterparty(counterparty.id) }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
        }
    }

    /// Счёт, к которому пора прокрутить карусель; nil — рано или нечего.
    private var pendingReveal: UUID? {
        guard isVisible,
              let id = viewModel.accountToReveal,
              viewModel.accounts.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        Group {
            if viewModel.isSearchActive && !searchQueryEmpty {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("Nothing found")
                        .font(Theme.Font.sheetTitle)
                        .foregroundStyle(Theme.Colors.ink)
                    Text("Try another word")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.ink2)
                }
            } else {
                Text(viewModel.emptyFeedMessage)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.ink2)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, Theme.Spacing.l)
    }

    private var searchQueryEmpty: Bool {
        viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Helpers

    /// Активация поиска по жесту «потянуть вниз»: как по тапу + запрос фокуса в шапке.
    private func activateSearchFromGesture() {
        withAnimation(reduceMotion ? nil : Theme.Animation.searchMorph) {
            viewModel.isSearchActive = true
        }
        viewModel.shouldFocusSearch = true
    }

    /// Тап по чипу тега в ленте → поиск по тегу (§4.3): без клавиатуры, лента — к началу результатов.
    private func searchByTag(_ tag: TagModel) {
        openSwipeRowId = nil
        withAnimation(reduceMotion ? nil : Theme.Animation.searchMorph) {
            viewModel.searchTag(tag)
            scrollPosition.scrollTo(edge: .top)
        }
    }

    /// Закрытие поиска: тап по пустому месту или свайп вверх (как ✕ в шапке).
    /// Фокус снимаем явно — клавиатура скрывается сразу, а не при удалении поля.
    private func closeSearch() {
        isSearchFocused = false
        viewModel.searchQuery = ""
        withAnimation(reduceMotion ? nil : Theme.Animation.searchMorph) {
            viewModel.isSearchActive = false
        }
    }

    /// Свайп по ленте снимает фокус (`scrollDismissesKeyboard`); при пустом запросе выходим из поиска,
    /// но только когда скролл остановился. Тап по полю до остановки отменяет выход.
    private func handleSearchFocusChange(_ focused: Bool) {
        if focused {
            pendingClose = false
            return
        }
        guard viewModel.isSearchActive, searchQueryEmpty else { return }
        if scrollPhase == .idle {
            closeSearchKeepingPosition()
        } else {
            pendingClose = true
        }
    }

    /// Выход из поиска после остановки скролла.
    /// - Строка поиска ещё видна → выход заметный, как по ✕: лента плавно возвращается к верху,
    ///   строка морфится в лупу, hero выезжает сверху.
    /// - Строка ушла за экран → выход незаметный: hero вставляется над экраном без анимации,
    ///   смещение растёт на его высоту, видимые строки остаются на месте.
    private func closeSearchKeepingPosition() {
        guard viewModel.isSearchActive, searchQueryEmpty else { return }
        let offset = scrollMetrics.offset
        // Видна ли шапка хоть частично — с учётом полосы под статус-баром.
        let searchBarVisible = offset < headerHeight + scrollMetrics.topInset
        // Строка видна (в т.ч. лента у самого верха) — одна анимированная ветка:
        // морфинг строки в лупу, выезд hero и плавный возврат ленты к верху.
        guard !searchBarVisible, heroHeight > 0 else {
            isSearchFocused = false
            withAnimation(reduceMotion ? nil : Theme.Animation.searchMorph) {
                viewModel.isSearchActive = false
                scrollPosition.scrollTo(edge: .top)
            }
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            viewModel.isSearchActive = false
            scrollPosition.scrollTo(y: offset + heroHeight)
        }
    }
}

/// Хранилище смещения ленты без наблюдения SwiftUI (см. `scrollMetrics`).
private final class ScrollMetrics {
    var offset: CGFloat = 0
    var topInset: CGFloat = 0
}
