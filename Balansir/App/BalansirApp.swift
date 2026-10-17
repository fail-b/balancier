import SwiftUI
import CoreData

@main
struct BalansirApp: App {
    private let persistence = PersistenceController.shared
    // Тема из Настроек (§4.8): меняется сразу, без перезапуска.
    @AppStorage(AppSettingsKey.appearance) private var appearance: AppearanceMode = .system
    /// Сплэш запуска: живёт весь процесс → показывается только при холодном старте.
    @State private var launchVM = LaunchViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(
                launchVM: launchVM,
                accountRepo: CoreDataAccountRepository(context: persistence.container.viewContext),
                categoryRepo: CoreDataCategoryRepository(context: persistence.container.viewContext),
                entryRepo: CoreDataEntryRepository(context: persistence.container.viewContext),
                tagRepo: CoreDataTagRepository(context: persistence.container.viewContext),
                counterpartyRepo: CoreDataCounterpartyRepository(context: persistence.container.viewContext)
            )
            .preferredColorScheme(appearance.colorScheme)
        }
    }
}
