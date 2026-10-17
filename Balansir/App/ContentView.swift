import SwiftUI

enum AppTab: Hashable {
    case home, statistics, accounts
    /// Не экран, а кнопка «+» справа от таб-бара (нативная «отдельная» вкладка iOS 26).
    /// Выбрать её нельзя — тап открывает шит новой операции.
    case add
}

struct ContentView: View {
    @State private var homeVM: HomeViewModel
    @State private var statisticsVM: StatisticsViewModel
    @State private var accountsVM: AccountsViewModel

    @State private var selectedTab: AppTab = .home
    @State private var addEntryVM: AddEntryViewModel?
    // Прокручен ли текущий экран ниже порога — тогда показываем сводку рядом со свёрнутым баром.
    @State private var isScrolled = false
    /// Онбординг (§4.9): `false` — показать (первый запуск или «Показать приветствие» в Настройках).
    @AppStorage(AppSettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false
    @State private var onboardingVM: OnboardingViewModel?
    /// Сплэш запуска закрылся (`RootView`). До этого онбординг не показываем — он накрыл бы анимацию.
    private let isLaunchFinished: Bool

    init(accountRepo: any AccountRepository,
         categoryRepo: any CategoryRepository,
         entryRepo: any EntryRepository,
         tagRepo: any TagRepository,
         counterpartyRepo: any CounterpartyRepository,
         isLaunchFinished: Bool = true) {
        self.isLaunchFinished = isLaunchFinished
        _homeVM = State(wrappedValue: HomeViewModel(accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: entryRepo,
                                                       tagRepo: tagRepo, counterpartyRepo: counterpartyRepo))
        _statisticsVM = State(wrappedValue: StatisticsViewModel(entryRepo: entryRepo))
        _accountsVM = State(wrappedValue: AccountsViewModel(accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: entryRepo,
                                                               counterpartyRepo: counterpartyRepo))
    }

    var body: some View {
        // Нативный таб-бар iOS 26: настоящий Liquid Glass, перетаскивание пальцем по вкладкам,
        // сворачивание при скролле. Свой FloatingTabBar больше не используется.
        TabView(selection: tabSelection) {
            Tab(value: AppTab.home) {
                NavigationStack {
                    HomeView(viewModel: homeVM, selectedTab: $selectedTab, isScrolled: $isScrolled)
                }
            } label: {
                tabLabel(String(localized: "Home"), icon: AppIcon.tabHome)
            }

            Tab(value: AppTab.statistics) {
                StatisticsView(viewModel: statisticsVM, isScrolled: $isScrolled)
            } label: {
                tabLabel(String(localized: "Statistics"), icon: AppIcon.tabStatistics)
            }

            Tab(value: AppTab.accounts) {
                AccountsView(viewModel: accountsVM, isScrolled: $isScrolled) { accountId in
                    // Тап по счёту → Главная с фильтром по нему (§4.5).
                    homeVM.showAccount(accountId)
                    selectedTab = .home
                }
            } label: {
                tabLabel(String(localized: "Accounts"), icon: AppIcon.tabAccounts)
            }

            // role: .search — система рисует вкладку отдельным круглым стеклом справа,
            // и при сворачивании бара он остаётся на месте. Используем это место под «+».
            Tab(value: AppTab.add, role: .search) {
                Color.clear
            } label: {
                // Круг остаётся системным стеклом, плюс — акцентным (решение владельца 2026-10-11).
                tabLabel(String(localized: "Add"), icon: AppIcon.add, tint: Theme.Colors.accent)
            }
        }
        .tint(Theme.Colors.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: isScrolled) {
            TabBarSummary(selectedTab: selectedTab, homeVM: homeVM)
        }
        .onChange(of: selectedTab) { isScrolled = false }
        .sheet(item: $addEntryVM, onDismiss: reloadAll) { vm in
            AddEntryView(viewModel: vm)
        }
        .fullScreenCover(item: $onboardingVM, onDismiss: {
            hasSeenOnboarding = true
            reloadAll()
        }) { vm in
            OnboardingView(viewModel: vm)
        }
        .task(id: isLaunchFinished) {
            guard isLaunchFinished else { return }
            await showOnboardingIfNeeded()
        }
        // «Показать приветствие» в Настройках сбрасывает флаг — показываем сразу, без проверки данных.
        .onChange(of: hasSeenOnboarding) { _, seen in
            if !seen, onboardingVM == nil { onboardingVM = homeVM.makeOnboardingViewModel() }
        }
    }

    /// Перехватывает тап по «+»: вкладка не переключается, открывается шит.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .add {
                    addEntryVM = homeVM.makeAddEntryViewModel()
                } else {
                    selectedTab = newValue
                }
            }
        )
    }

    private func tabLabel(_ title: String, icon: String, tint: Color? = nil) -> some View {
        Label {
            Text(title)
        } icon: {
            if let tint {
                AppIcon.image(named: icon)
                    .foregroundStyle(tint)
            } else {
                AppIcon.image(named: icon)
            }
        }
    }

    /// Первый запуск: показать онбординг, если у пользователя ещё нет своих данных,
    /// иначе (обновление с уже заполненной базой) — просто отметить его пройденным.
    private func showOnboardingIfNeeded() async {
        guard !hasSeenOnboarding, onboardingVM == nil else { return }
        let vm = homeVM.makeOnboardingViewModel()
        if await vm.needsOnboarding() {
            onboardingVM = vm
        } else {
            hasSeenOnboarding = true
        }
    }

    private func reloadAll() {
        Task {
            await homeVM.load()
            await statisticsVM.load()
            await accountsVM.load()
        }
    }
}
