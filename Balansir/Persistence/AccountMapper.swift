import Foundation

extension Account {
    func toModel() -> AccountModel {
        AccountModel(
            id: id,
            name: name,
            initialBalance: MinorUnits.fromMinor(initialBalanceMinor, currency: currency),
            currency: currency,
            colorHex: colorHex,
            iconName: iconName,
            accountType: AccountType(rawValue: accountType) ?? .debit,
            sortOrder: sortOrder,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt ?? createdAt
        )
    }

    func update(from model: AccountModel) {
        name = model.name
        initialBalanceMinor = MinorUnits.toMinor(model.initialBalance, currency: model.currency)
        currency = model.currency
        colorHex = model.colorHex
        iconName = model.iconName
        accountType = model.accountType.rawValue
        sortOrder = model.sortOrder
        isArchived = model.isArchived
        updatedAt = Date()
    }
}
