import SwiftUI

/// Иконка контрагента (§4.11) — как у категории: круг `fill`, иконка `ink`, точка цвета контрагента.
struct CounterpartyIcon: View {
    let counterparty: CounterpartyModel
    var size: CGFloat = Theme.Row.iconSize

    var body: some View {
        DotIcon(iconName: counterparty.iconName, colorHex: counterparty.colorHex, size: size)
    }
}
