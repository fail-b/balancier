import SwiftUI

/// Модальный экран «Контрагенты» (§4.11): сводка долгов, список, добавление, изменение, удаление.
struct CounterpartiesView: View {
    @Bindable var viewModel: CounterpartiesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var formVM: CounterpartyFormViewModel?
    /// Строка, открытая свайпом; nil — ни одна.
    @State private var openSwipeRowId: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    DebtTotalsCard(totals: viewModel.totals)
                    if viewModel.counterparties.isEmpty {
                        Text("No counterparties yet. Add them here or in the new transaction sheet.")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.ink2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xxl)
                    } else {
                        list
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(Theme.Colors.background)
            .onScrollPhaseChange { _, newPhase in
                if newPhase == .interacting, openSwipeRowId != nil { openSwipeRowId = nil }
            }
            .navigationTitle("Counterparties")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        formVM = viewModel.makeFormViewModel(for: nil)
                    } label: {
                        AppIcon.image(named: AppIcon.add)
                    }
                    .accessibilityLabel(Text("New counterparty"))
                }
            }
            .sheet(item: $formVM, onDismiss: { Task { await viewModel.load() } }) { vm in
                CounterpartyFormView(viewModel: vm)
            }
            .task { await viewModel.load() }
            .alert(
                Text("Delete “\(viewModel.pendingDeletion?.name ?? "")”?"),
                isPresented: Binding(
                    get: { viewModel.pendingDeletion != nil },
                    set: { if !$0 { viewModel.cancelDelete() } }
                )
            ) {
                Button("Delete", role: .destructive) { Task { await viewModel.confirmDelete() } }
                Button("Cancel", role: .cancel) { viewModel.cancelDelete() }
            } message: {
                Text(viewModel.pendingDeletionMessage)
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.counterparties) { counterparty in
                SwipeToDeleteRow(
                    id: counterparty.id,
                    openRowId: $openSwipeRowId,
                    content: { row(counterparty) },
                    onTap: { formVM = viewModel.makeFormViewModel(for: counterparty) },
                    onDelete: { await viewModel.requestDelete(counterparty) }
                )
                // Долгое нажатие → меню; можно не отпуская провести палец на пункт.
                .contextMenu {
                    Button {
                        formVM = viewModel.makeFormViewModel(for: counterparty)
                    } label: {
                        Label { Text("Edit") } icon: { AppIcon.image(named: AppIcon.edit) }
                    }
                    Button(role: .destructive) {
                        Task { await viewModel.requestDelete(counterparty) }
                    } label: {
                        Label { Text("Delete") } icon: { AppIcon.image(named: AppIcon.trash) }
                    }
                }
                if counterparty.id != viewModel.counterparties.last?.id {
                    Rectangle()
                        .fill(Theme.Colors.separator)
                        .frame(height: Theme.Size.hairline)
                        .padding(.leading, Theme.Row.separatorInset)
                }
            }
        }
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func row(_ counterparty: CounterpartyModel) -> some View {
        let debt = viewModel.debt(for: counterparty)
        return HStack(spacing: Theme.Spacing.m) {
            CounterpartyIcon(counterparty: counterparty)
            Text(counterparty.name)
                .font(Theme.Font.rowTitle)
                .foregroundStyle(Theme.Colors.ink)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.s)
            Text(MoneyFormatter.debt(debt))
                .font(Theme.Font.rowAmount)
                .monospacedDigit()
                .foregroundStyle(Theme.debtColor(for: debt))
                .lineLimit(1)
                .minimumScaleFactor(Theme.Size.summaryMinScale)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Row.verticalPadding)
        .contentShape(Rectangle())
    }
}

/// Сводка «Мне должны · Я должен» (§4.11).
struct DebtTotalsCard: View {
    let totals: DebtService.Totals

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            column(title: "Owed to me", amount: totals.owedToMe, color: Theme.Colors.debtOwedToMe, alignment: .leading)
            Spacer(minLength: Theme.Spacing.s)
            column(title: "I owe", amount: totals.iOwe, color: Theme.Colors.debtIOwe, alignment: .trailing)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private func column(title: LocalizedStringKey, amount: Decimal, color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Theme.Row.textSpacing) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.ink2)
            Text(MoneyFormatter.format(amount))
                .font(Theme.Font.bodyAmount)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(Theme.Size.summaryMinScale)
        }
    }
}
