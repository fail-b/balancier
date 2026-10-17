import SwiftUI

/// Корень окна: приложение и поверх него сплэш запуска.
/// `ContentView` строится сразу под сплэшем — экраны загружают данные, пока идёт анимация.
/// Онбординг ждёт конца сплэша (`isLaunchFinished`), иначе его fullScreenCover накрыл бы анимацию.
struct RootView: View {
    let launchVM: LaunchViewModel
    let accountRepo: any AccountRepository
    let categoryRepo: any CategoryRepository
    let entryRepo: any EntryRepository
    let tagRepo: any TagRepository
    let counterpartyRepo: any CounterpartyRepository

    var body: some View {
        ZStack {
            ContentView(
                accountRepo: accountRepo,
                categoryRepo: categoryRepo,
                entryRepo: entryRepo,
                tagRepo: tagRepo,
                counterpartyRepo: counterpartyRepo,
                isLaunchFinished: !launchVM.isSplashVisible
            )
            .accessibilityHidden(launchVM.isSplashVisible)

            if launchVM.isSplashVisible {
                BalansirSplashCoinView { launchVM.animationFinished() }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(Theme.Splash.dismissAnimation, value: launchVM.isSplashVisible)
        .task { await launchVM.prepare() }
    }
}
