import SwiftUI

struct AddEntryView: View {
    @Bindable var viewModel: AddEntryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var path: [AccountPickerTarget] = []
    @State private var showDatePicker = false
    /// Поле с системной клавиатурой: «Заметка», новый тег или новый контрагент в карусели.
    private enum Field { case note, newTag, newCounterparty }
    /// Пока фокус в поле — вместо своей цифровой клавиатуры системная,
    /// а «Сохранить» остаётся над ней (правило «минимум тапов»).
    @FocusState private var focusedField: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack(path: $path) {
            mainContent
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AccountPickerTarget.self) { target in
                    pickerView(for: target)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationDragIndicator(.visible)
        .task { await viewModel.load() }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Rename tag", isPresented: Binding(
            get: { viewModel.tagBeingRenamed != nil },
            set: { if !$0 { viewModel.cancelRename() } }
        )) {
            TextField("Tag name", text: $viewModel.renameText)
            Button("Cancel", role: .cancel) { viewModel.cancelRename() }
            Button("Save") {
                // Тег и имя берём сейчас: после закрытия алерта состояние переименования сбрасывается.
                guard let tag = viewModel.tagBeingRenamed else { return }
                let name = viewModel.renameText
                Task { await viewModel.rename(tag, to: name) }
            }
        }
    }

    // MARK: - Основной экран

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            // Верх прокручивается, если над системной клавиатурой не хватает места (маленькие iPhone),
            // при этом «Сохранить» остаётся видимой.
            ScrollView {
                VStack(spacing: 0) {
                    typeSegment
                        .padding(.top, Theme.Spacing.l)
                    amountView
                        .padding(.top, Theme.Spacing.xl)
                    card
                        .padding(.top, Theme.Spacing.l)
                }
                .padding(.bottom, Theme.Spacing.l)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            if focusedField == nil {
                NumpadView(layout: .amount) { viewModel.press($0) }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            saveButton
                .padding(.top, Theme.Spacing.m)
        }
        .animation(reduceMotion ? nil : Theme.Animation.numpadToggle, value: focusedField)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.s)
        // Тап в любое место мимо полей прячет системную клавиатуру
        // и возвращает цифровую. Кнопки и само поле обрабатывают свои тапы раньше.
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .background(Theme.Colors.background)
    }

    // MARK: - Шапка

    private var header: some View {
        ZStack {
            Text(viewModel.isEditing ? "Edit Transaction" : "New Transaction")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.Colors.ink)
            HStack {
                Button { dismiss() } label: {
                    AppIcon.image(named: AppIcon.close)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                        .frame(width: 44, height: 44)
                        .glassEffect(in: .circle)
                }
                .buttonStyle(.plain)
                Spacer()
                dateChip
            }
        }
        .padding(.top, Theme.Spacing.s)
    }

    private var dateChip: some View {
        Button {
            focusedField = nil
            showDatePicker = true
        } label: {
            HStack(spacing: 6) {
                AppIcon.image(named: AppIcon.calendar).font(.system(size: 15))
                Text(dateLabel).font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, Theme.Spacing.m)
            .frame(height: 44)
            .glassEffect(in: .capsule)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("Date", selection: $viewModel.date, in: ...viewModel.latestAllowedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Theme.Colors.accent)
                .padding(.horizontal, Theme.Spacing.l)
                .navigationTitle("Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showDatePicker = false }
                    }
                }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var dateLabel: String {
        if Calendar.current.isDateInToday(viewModel.date) { return String(localized: "Today") }
        return viewModel.date.formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: - Сегмент типа

    private var typeSegment: some View {
        segment(EntryType.allCases, title: \.title, isOptionActive: { viewModel.selectedType == $0 }) { type in
            viewModel.selectedType = type
            viewModel.onTypeChanged()
        }
    }

    /// Сегмент «Я отправил / Мне пришли» у долга (§4.11).
    private var debtDirectionSegment: some View {
        segment(DebtDirection.allCases, title: \.title, isOptionActive: { viewModel.debtDirection == $0 }) {
            viewModel.debtDirection = $0
        }
    }

    /// Сегмент как у типа операции: `fill`, активный — `card` с тенью.
    private func segment<T: Hashable>(_ options: [T], title: KeyPath<T, String>, isOptionActive: @escaping (T) -> Bool,
                                      onSelect: @escaping (T) -> Void) -> some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isActive = isOptionActive(option)
                Button {
                    focusedField = nil
                    onSelect(option)
                } label: {
                    Text(option[keyPath: title])
                        .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? Theme.Colors.ink : Theme.Colors.ink2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background {
                            if isActive {
                                RoundedRectangle(cornerRadius: Theme.Radius.s)
                                    .fill(Theme.Colors.card)
                                    .shadow(color: Theme.Colors.shadow, radius: 4, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.m))
    }

    // MARK: - Сумма

    private var amountView: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(viewModel.formattedAmount)
                .font(Theme.Font.amountInput)
                .tracking(Theme.Font.Tracking.amountInput)
                .foregroundStyle(viewModel.amountInput.isEmpty ? Theme.Colors.ink2 : Theme.Colors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(viewModel.currencySymbol)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.Colors.ink2)
            caret
                .opacity(focusedField != nil ? 0 : 1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var caret: some View {
        // phaseAnimator анимирует только opacity и не вмешивается в раскладку,
        // поэтому каретка мигает на месте, а не «прилетает» из угла экрана.
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Theme.Colors.accent)
            .frame(width: 3, height: 52)
            .phaseAnimator([1.0, 0.0]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in .easeInOut(duration: 0.6) }
    }

    // MARK: - Карточка

    private var card: some View {
        VStack(spacing: 0) {
            if viewModel.selectedType == .debt {
                debtSection
                Divider().padding(.leading, Theme.Spacing.l)
                accountRow(target: .from, label: "Account")
            } else if viewModel.selectedType != .transfer {
                categoryStrip
                    .padding(.vertical, Theme.Spacing.m)
                if viewModel.showsTags {
                    tagStrip
                        .padding(.bottom, Theme.Spacing.m)
                }
                Divider().padding(.leading, Theme.Spacing.l)
                accountRow(target: .from, label: "Account")
            } else {
                accountRow(target: .from, label: "From account")
                Divider().padding(.leading, Theme.Spacing.l)
                accountRow(target: .to, label: "To account")
            }
            Divider().padding(.leading, Theme.Spacing.l)
            noteRow
        }
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(viewModel.filteredCategories) { category in
                    categoryCell(category)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Theme.Spacing.s)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    private func categoryCell(_ category: CategoryModel) -> some View {
        let isSelected = viewModel.selectedCategory?.id == category.id
        return Button {
            focusedField = nil
            viewModel.selectedCategory = category
        } label: {
            VStack(spacing: Theme.AddEntry.categoryLabelGap) {
                // Рамка шире иконки — место под кольцо выбора, чтобы оно не обрезалось.
                ZStack {
                    if isSelected {
                        Circle().strokeBorder(Theme.Colors.accent, lineWidth: Theme.AddEntry.categoryRingWidth)
                    }
                    CategoryIcon(category: category, size: Theme.AddEntry.categoryIconSize)
                }
                .frame(width: Theme.AddEntry.categoryRingFrame, height: Theme.AddEntry.categoryRingFrame)
                Text(category.name)
                    .font(isSelected ? Theme.Font.categoryCellLabelSelected : Theme.Font.categoryCellLabel)
                    .foregroundStyle(isSelected ? Theme.Colors.ink : Theme.Colors.ink2)
                    .lineLimit(1)
            }
            .frame(width: Theme.AddEntry.categoryCellWidth)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Теги (§4.7)

    /// Карусель всех тегов: первыми — чаще использованные с выбранной категорией. Тап — выбрать/снять,
    /// долгий тап — меню «Переименовать / Скрыть», последняя ячейка «+» — поле нового тега.
    private var tagStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(viewModel.carouselTags) { tag in
                        tagCell(tag)
                    }
                    addTagCell
                        .id(Field.newTag)
                }
                .padding(.horizontal, Theme.Spacing.l)
            }
            .onChange(of: viewModel.isAddingTag) { _, isAdding in
                if isAdding { withAnimation { proxy.scrollTo(Field.newTag, anchor: .trailing) } }
            }
        }
        // Ушёл фокус из поля нового тега (тап мимо, «Сохранить») — введённое сохраняется.
        .onChange(of: focusedField) { old, new in
            if old == .newTag, new != .newTag, viewModel.isAddingTag {
                Task { await viewModel.commitNewTag() }
            }
        }
    }

    private func tagCell(_ tag: TagModel) -> some View {
        let isSelected = viewModel.isSelected(tag)
        return Button {
            focusedField = nil
            viewModel.toggleTag(tag)
        } label: {
            Text(verbatim: "#\(tag.name)")
                .font(Theme.Font.tagCarousel)
                .foregroundStyle(isSelected ? Theme.Colors.onColor : Theme.Colors.ink)
                .lineLimit(1)
                .padding(.horizontal, Theme.TagSize.carouselHorizontalPadding)
                .frame(height: Theme.TagSize.carouselHeight)
                .background(isSelected ? Theme.Colors.accent : Theme.Colors.fill, in: Capsule())
        }
        .buttonStyle(.plain)
        // Системное контекстное меню: можно не отпускать палец и сразу провести до пункта.
        .contextMenu {
            Button {
                viewModel.beginRename(tag)
            } label: {
                Label { Text("Rename") } icon: { AppIcon.image(named: AppIcon.edit) }
            }
            Button(role: .destructive) {
                Task { await viewModel.hideTag(tag) }
            } label: {
                Label { Text("Hide") } icon: { AppIcon.image(named: AppIcon.archive) }
            }
        }
    }

    @ViewBuilder
    private var addTagCell: some View {
        if viewModel.isAddingTag {
            TextField("New tag", text: $viewModel.newTagName)
                .font(Theme.Font.tagCarousel)
                .foregroundStyle(Theme.Colors.ink)
                .focused($focusedField, equals: .newTag)
                .submitLabel(.done)
                .onSubmit { Task { await viewModel.commitNewTag() } }
                .padding(.horizontal, Theme.TagSize.carouselHorizontalPadding)
                .frame(width: Theme.TagSize.newTagFieldWidth, height: Theme.TagSize.carouselHeight)
                .background(Theme.Colors.fill, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.Colors.accent, lineWidth: Theme.TagSize.newTagFieldBorder))
                .onAppear { focusedField = .newTag }
        } else {
            Button {
                viewModel.startAddingTag()
                focusedField = .newTag
            } label: {
                AppIcon.image(named: AppIcon.add)
                    .font(Theme.Font.tagCarousel)
                    .foregroundStyle(Theme.Colors.ink2)
                    .frame(width: Theme.TagSize.carouselHeight, height: Theme.TagSize.carouselHeight)
                    .background(Theme.Colors.fill, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("New tag"))
        }
    }

    // MARK: - Долг (§4.11)

    /// Направление, карусель контрагентов и подсказка о текущем долге.
    private var debtSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            debtDirectionSegment
                .padding(.horizontal, Theme.Spacing.l)
            counterpartyStrip
            if let hint = viewModel.counterpartyHint {
                Text(hint)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.debtColor(for: viewModel.selectedCounterpartyDebt ?? 0))
                    .padding(.horizontal, Theme.Spacing.l)
            }
        }
        .padding(.vertical, Theme.Spacing.m)
    }

    /// Карусель контрагентов: капсулы как у тегов, в конце «+» — поле нового контрагента.
    private var counterpartyStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(viewModel.carouselCounterparties) { counterparty in
                        counterpartyCell(counterparty)
                    }
                    addCounterpartyCell
                        .id(Field.newCounterparty)
                }
                .padding(.horizontal, Theme.Spacing.l)
            }
            .onChange(of: viewModel.isAddingCounterparty) { _, isAdding in
                if isAdding { withAnimation { proxy.scrollTo(Field.newCounterparty, anchor: .trailing) } }
            }
        }
        // Ушёл фокус из поля (тап мимо, «Сохранить») — введённое сохраняется.
        .onChange(of: focusedField) { old, new in
            if old == .newCounterparty, new != .newCounterparty, viewModel.isAddingCounterparty {
                Task { await viewModel.commitNewCounterparty() }
            }
        }
    }

    private func counterpartyCell(_ counterparty: CounterpartyModel) -> some View {
        let isSelected = viewModel.selectedCounterparty?.id == counterparty.id
        return Button {
            focusedField = nil
            viewModel.selectCounterparty(counterparty)
        } label: {
            Text(counterparty.name)
                .font(Theme.Font.tagCarousel)
                .foregroundStyle(isSelected ? Theme.Colors.onColor : Theme.Colors.ink)
                .lineLimit(1)
                .padding(.horizontal, Theme.TagSize.carouselHorizontalPadding)
                .frame(height: Theme.TagSize.carouselHeight)
                .background(isSelected ? Theme.Colors.accent : Theme.Colors.fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var addCounterpartyCell: some View {
        if viewModel.isAddingCounterparty {
            TextField("New counterparty", text: $viewModel.newCounterpartyName)
                .font(Theme.Font.tagCarousel)
                .foregroundStyle(Theme.Colors.ink)
                .focused($focusedField, equals: .newCounterparty)
                .submitLabel(.done)
                .onSubmit { Task { await viewModel.commitNewCounterparty() } }
                .padding(.horizontal, Theme.TagSize.carouselHorizontalPadding)
                .frame(width: Theme.TagSize.newTagFieldWidth, height: Theme.TagSize.carouselHeight)
                .background(Theme.Colors.fill, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.Colors.accent, lineWidth: Theme.TagSize.newTagFieldBorder))
                .onAppear { focusedField = .newCounterparty }
        } else {
            Button {
                viewModel.startAddingCounterparty()
                focusedField = .newCounterparty
            } label: {
                AppIcon.image(named: AppIcon.add)
                    .font(Theme.Font.tagCarousel)
                    .foregroundStyle(Theme.Colors.ink2)
                    .frame(width: Theme.TagSize.carouselHeight, height: Theme.TagSize.carouselHeight)
                    .background(Theme.Colors.fill, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("New counterparty"))
        }
    }

    private func accountRow(target: AccountPickerTarget, label: LocalizedStringKey) -> some View {
        let account = target == .from ? viewModel.selectedAccount : viewModel.selectedToAccount
        return Button {
            focusedField = nil
            path.append(target)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                AccountColorCard(colorHex: account?.colorHex ?? "#CCCCCC")
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.ink2)
                    Text(account.map { viewModel.subtitle(for: $0) } ?? String(localized: "Choose an account"))
                        .font(Theme.Font.rowTitle)
                        .foregroundStyle(Theme.Colors.ink)
                }
                Spacer()
                AppIcon.image(named: AppIcon.forward)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink2)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var noteRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            AppIcon.image(named: AppIcon.note)
                .font(.system(size: 17))
                .foregroundStyle(Theme.Colors.ink2)
            TextField("Note", text: $viewModel.note)
                .font(Theme.Font.rowTitle)
                .foregroundStyle(Theme.Colors.ink)
                .focused($focusedField, equals: .note)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = .note }
    }

    // MARK: - Сохранить

    private var saveButton: some View {
        Button {
            Task {
                await viewModel.save()
                if viewModel.errorMessage == nil { dismiss() }
            }
        } label: {
            Text("Save")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Colors.onColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.l))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSave)
        .opacity(viewModel.canSave ? 1 : 0.4)
    }

    // MARK: - Выбор счёта

    private func pickerView(for target: AccountPickerTarget) -> some View {
        let title: String
        let selectedId: UUID?
        switch target {
        case .from:
            title = viewModel.selectedType == .transfer ? String(localized: "From account") : String(localized: "Account")
            selectedId = viewModel.selectedAccount?.id
        case .to:
            title = String(localized: "To account")
            selectedId = viewModel.selectedToAccount?.id
        }
        return AccountPickerView(
            title: title,
            accounts: viewModel.accounts,
            selectedId: selectedId,
            balanceText: { MoneyFormatter.format(viewModel.balance(for: $0), currency: $0.currency) },
            onSelect: { account in
                if target == .from { viewModel.selectedAccount = account } else { viewModel.selectedToAccount = account }
                if !path.isEmpty { path.removeLast() }
            },
            onBack: { if !path.isEmpty { path.removeLast() } }
        )
    }
}
