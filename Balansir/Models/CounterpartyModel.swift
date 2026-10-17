import Foundation

/// Контрагент долга (§4.11): с кем долг — человек или общая трата («мама», «кофе», «поездка»).
/// Долг по нему не хранится, а считается из операций (`DebtService`).
struct CounterpartyModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var sortOrder: Int32
    /// Мягко удалён: пропадает из каруселей, списков и итогов долгов, операции с ним остаются.
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date
}

extension CounterpartyModel {
    /// Новый контрагент с именем: иконка `person`, цвет — следующий из палитры, в конец списка.
    static func new(name: String, existing: [CounterpartyModel], now: Date = Date()) -> CounterpartyModel {
        let palette = Theme.Palette.hexColors
        return CounterpartyModel(
            id: UUID(),
            name: name,
            colorHex: palette.isEmpty ? "#4A90D9" : palette[existing.count % palette.count],
            iconName: AppIcon.counterparty,
            sortOrder: (existing.map(\.sortOrder).max() ?? -1) + 1,
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )
    }
}
