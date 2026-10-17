import Foundation

/// Форма контрагента (§4.11): имя, цвет, иконка — как у категории.
@Observable
final class CounterpartyFormViewModel: Identifiable {
    let id = UUID()
    var name = ""
    var selectedColorHex: String
    var selectedIcon = AppIcon.counterparty
    var errorMessage: String?

    private let editing: CounterpartyModel?
    private let counterpartyRepo: any CounterpartyRepository
    private let locale: Locale

    init(counterparty: CounterpartyModel? = nil, counterpartyRepo: any CounterpartyRepository, locale: Locale = .current) {
        self.editing = counterparty
        self.counterpartyRepo = counterpartyRepo
        self.locale = locale
        selectedColorHex = Theme.Palette.hexColors.first ?? "#4A90D9"
        if let counterparty {
            name = counterparty.name
            selectedColorHex = counterparty.colorHex
            selectedIcon = counterparty.iconName
        }
    }

    var isEditing: Bool { editing != nil }
    var canSave: Bool { !TagUsageService.cleanName(name).isEmpty }

    /// Сохраняет. Имя, занятое другим (не удалённым) контрагентом, — ошибка.
    /// Новый с именем удалённого — возвращает удалённого (операции с ним снова в итогах).
    func save() async {
        let cleanName = TagUsageService.cleanName(name)
        guard !cleanName.isEmpty else { return }
        do {
            let all = try await counterpartyRepo.fetchAll()
            let sameName = all.filter { $0.id != editing?.id && TagUsageService.sameName($0.name, cleanName, locale: locale) }
            if sameName.contains(where: { !$0.isArchived }) {
                errorMessage = String(localized: "A counterparty with this name already exists.")
                return
            }
            var model: CounterpartyModel
            if let editing {
                model = editing
            } else if let archived = sameName.first {
                model = archived
                model.isArchived = false
            } else {
                model = CounterpartyModel.new(name: cleanName, existing: all)
            }
            model.name = cleanName
            model.colorHex = selectedColorHex
            model.iconName = selectedIcon
            model.updatedAt = Date()
            try await counterpartyRepo.save(model)
        } catch { errorMessage = error.localizedDescription }
    }
}
