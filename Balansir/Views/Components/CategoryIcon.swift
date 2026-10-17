import SwiftUI

/// Иконка категории: круг `fill`, контурная иконка `ink`, справа снизу точка цвета категории.
/// Стиль один («Точка»), выбор стиля убран по решению владельца 2026-10-11.
struct CategoryIcon: View {
    let category: CategoryModel
    var size: CGFloat = 40

    var body: some View {
        DotIcon(iconName: category.iconName, colorHex: category.colorHex, size: size)
    }
}

/// Круг `fill` с контурной иконкой и точкой цвета справа снизу — общий для категории и контрагента.
struct DotIcon: View {
    let iconName: String
    let colorHex: String
    var size: CGFloat = 40

    private var iconSize: CGFloat { size * 0.45 }
    private var dotColor: Color { Color(hex: colorHex) ?? Theme.Colors.fallback }

    var body: some View {
        Circle()
            .fill(Theme.Colors.fill)
            .frame(width: size, height: size)
            .overlay {
                AppIcon.image(named: iconName)
                    .font(.system(size: iconSize))
                    .foregroundStyle(Theme.Colors.ink)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 12, height: 12)
                    .overlay { Circle().strokeBorder(Theme.Colors.card, lineWidth: 2) }
                    .offset(x: 2, y: 2)
            }
    }
}
