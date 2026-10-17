import Foundation

extension Counterparty {
    func toModel() -> CounterpartyModel {
        CounterpartyModel(
            id: id,
            name: name,
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: sortOrder,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt ?? createdAt
        )
    }

    func update(from model: CounterpartyModel) {
        name = model.name
        colorHex = model.colorHex
        iconName = model.iconName
        sortOrder = model.sortOrder
        isArchived = model.isArchived
        updatedAt = Date()
    }
}
