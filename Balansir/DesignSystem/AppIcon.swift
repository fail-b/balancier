import SwiftUI

enum AppIcon {
    // Навигация и таб-бар
    static let tabHome = "house"
    static let tabHomeFill = "house.fill"
    static let tabStatistics = "chart.pie"
    static let tabStatisticsFill = "chart.pie.fill"
    static let tabAccounts = "creditcard"
    static let tabAccountsFill = "creditcard.fill"

    // Управляющие кнопки
    static let add = "plus"
    static let close = "xmark"
    static let closeCircle = "xmark.circle.fill"
    static let back = "chevron.left"
    static let forward = "chevron.right"
    static let chevronDown = "chevron.down"
    static let checkmark = "checkmark"
    static let settings = "gearshape"
    static let search = "magnifyingglass"
    static let calendar = "calendar"
    static let note = "text.alignleft"
    static let transfer = "arrow.left.arrow.right"
    static let backspace = "delete.left"
    static let export = "square.and.arrow.up"
    static let importData = "square.and.arrow.down"
    static let trash = "trash"
    static let edit = "pencil"
    /// «Скрыть» счёт/категорию (мягкое удаление).
    static let archive = "archivebox"
    /// Контрагент долга по умолчанию и карточка «Долги» на вкладке «Счета» (§4.11).
    static let counterparty = "person"
    static let debts = "person.2"

    // Категории (пикеры)
    static let accountPicker: [String] = [
        "creditcard", "banknote", "building.columns", "wallet.pass",
        "dollarsign.circle", "eurosign.circle", "sterlingsign.circle",
        "briefcase", "house", "car", "airplane", "cart",
    ]

    static let categoryPicker: [String] = [
        "fork.knife", "cart", "tram", "airplane", "car",
        "wrench.and.screwdriver", "tshirt", "creditcard",
        "star", "gamecontroller", "heart.text.square", "pills",
        "gift", "house", "briefcase", "iphone", "phone",
        "figure.run", "building.2",
        "banknote", "laptopcomputer", "percent",
        "arrow.uturn.left", "ellipsis.circle",
    ]

    /// Иконки контрагента (§4.11).
    static let counterpartyPicker: [String] = [
        "person", "person.2", "figure.2.and.child.holdinghands", "heart",
        "house", "briefcase", "building.2", "cup.and.saucer",
        "airplane", "car", "gift", "sportscourt",
    ]

    // Рендерит иконку: сначала ищет кастомный ассет, затем SF Symbol
    static func image(named name: String) -> Image {
        if UIImage(named: name) != nil {
            return Image(name)
        }
        return Image(systemName: name)
    }
}
