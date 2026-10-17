import SwiftUI

/// Форма контрагента (§4.11): имя, цвет, иконка — как у категории.
struct CounterpartyFormView: View {
    @Bindable var viewModel: CounterpartyFormViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                // Отдельный ключ: у категории «Название», у контрагента — «Имя».
                Section(String(localized: "counterparty.form.name", defaultValue: "Name")) {
                    TextField("E.g., Mom", text: $viewModel.name)
                }
                Section("Color") { colorPicker }
                Section("Icon") { iconPicker }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Counterparty" : "New Counterparty")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.save()
                            if viewModel.errorMessage == nil { dismiss() }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }

    private var colorPicker: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
            ForEach(Theme.Palette.hexColors, id: \.self) { hex in
                Button { viewModel.selectedColorHex = hex } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? Theme.Colors.fallback)
                        .frame(height: Theme.Counterparties.pickerCellHeight)
                        .overlay {
                            if viewModel.selectedColorHex == hex {
                                AppIcon.image(named: AppIcon.checkmark)
                                    .font(Theme.Font.caption.weight(.bold))
                                    .foregroundStyle(Theme.Colors.onColor)
                            }
                        }
                }
                // Без .plain в строке Form срабатывает последняя кнопка ряда (долг №8).
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var iconPicker: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
            ForEach(AppIcon.counterpartyPicker, id: \.self) { icon in
                let isSelected = viewModel.selectedIcon == icon
                Button { viewModel.selectedIcon = icon } label: {
                    ZStack {
                        if isSelected {
                            Circle().strokeBorder(Theme.Colors.accent, lineWidth: Theme.AddEntry.categoryRingWidth)
                        }
                        DotIcon(iconName: icon, colorHex: viewModel.selectedColorHex, size: Theme.Counterparties.pickerIconSize)
                    }
                    .frame(height: Theme.Counterparties.pickerCellHeight + Theme.Spacing.s)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}
