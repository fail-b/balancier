import Testing
import Foundation
@testable import Balansir

@Suite("AddEntryViewModel — теги")
@MainActor
struct AddEntryTagsTests {

    private struct Env {
        let vm: AddEntryViewModel
        let tagRepo: MockTagRepository
        let entryRepo: MockEntryRepository
        let account: AccountModel
        let category: CategoryModel
    }

    private func makeEnv(tags: [TagModel] = [], entries: [EntryModel] = [], editing: EntryModel? = nil) async -> Env {
        let account = AccountModel.makeTest()
        let category = editing?.category ?? CategoryModel.makeTest(name: "Машина")
        let accountRepo = MockAccountRepository()
        accountRepo.accounts = [account]
        let categoryRepo = MockCategoryRepository()
        categoryRepo.categories = [category]
        let entryRepo = MockEntryRepository()
        entryRepo.entries = entries
        let tagRepo = MockTagRepository()
        tagRepo.tags = tags
        let vm = AddEntryViewModel(entry: editing, accountRepo: accountRepo, categoryRepo: categoryRepo, entryRepo: entryRepo,
                                   tagRepo: tagRepo, counterpartyRepo: MockCounterpartyRepository(), locale: TestLocale.ru)
        await vm.load()
        return Env(vm: vm, tagRepo: tagRepo, entryRepo: entryRepo, account: account, category: category)
    }

    @Test func тап_выбирает_повторный_снимает() async {
        let fuel = TagModel.makeTest(name: "Бензин")
        let env = await makeEnv(tags: [fuel])
        env.vm.toggleTag(fuel)
        #expect(env.vm.selectedTags.map(\.id) == [fuel.id])
        env.vm.toggleTag(fuel)
        #expect(env.vm.selectedTags.isEmpty)
    }

    @Test func у_операции_один_тег_новый_заменяет() async {
        let a = TagModel.makeTest(name: "А")
        let b = TagModel.makeTest(name: "Б")
        let env = await makeEnv(tags: [a, b])
        env.vm.toggleTag(a)
        env.vm.toggleTag(b)
        #expect(env.vm.selectedTags.map(\.id) == [b.id])
    }

    @Test func сохранение_передаёт_тег() async {
        let fuel = TagModel.makeTest(name: "Бензин")
        let env = await makeEnv(tags: [fuel])
        env.vm.amountString = "500"
        env.vm.toggleTag(fuel)
        await env.vm.save()
        #expect(env.entryRepo.savedEntry?.tags.map(\.id) == [fuel.id])
    }

    @Test func у_перевода_тегов_нет() async {
        let fuel = TagModel.makeTest(name: "Бензин")
        let env = await makeEnv(tags: [fuel])
        env.vm.toggleTag(fuel)
        env.vm.selectedType = .transfer
        env.vm.onTypeChanged()
        #expect(!env.vm.showsTags)
        #expect(env.vm.selectedTags.isEmpty)
    }

    @Test func карусель_по_частоте_с_категорией_без_скрытых() async {
        let car = CategoryModel.makeTest(name: "Машина")
        let other = CategoryModel.makeTest(name: "Еда")
        let fuel = TagModel.makeTest(name: "Бензин")
        let coffee = TagModel.makeTest(name: "Кофе")
        let hidden = TagModel.makeTest(name: "Старый", isArchived: true)
        let entries = [
            EntryModel.makeTest(type: .expense, amount: 1, category: car, tags: [fuel]),
            EntryModel.makeTest(type: .expense, amount: 1, category: other, tags: [coffee]),
            EntryModel.makeTest(type: .expense, amount: 1, category: other, tags: [coffee]),
        ]
        let env = await makeEnv(tags: [coffee, hidden, fuel], entries: entries)
        env.vm.selectedCategory = car
        #expect(env.vm.carouselTags.map(\.name) == ["Бензин", "Кофе"])
        env.vm.selectedCategory = other
        #expect(env.vm.carouselTags.map(\.name) == ["Кофе", "Бензин"])
    }

    @Test func новый_тег_создаётся_и_выбирается() async {
        let env = await makeEnv()
        env.vm.startAddingTag()
        env.vm.newTagName = "  Мойка "
        await env.vm.commitNewTag()
        #expect(env.tagRepo.tags.map(\.name) == ["Мойка"])
        #expect(env.vm.selectedTags.map(\.name) == ["Мойка"])
        #expect(!env.vm.isAddingTag)
    }

    @Test func пустое_имя_не_создаёт_тег() async {
        let env = await makeEnv()
        env.vm.startAddingTag()
        env.vm.newTagName = "   "
        await env.vm.commitNewTag()
        #expect(env.tagRepo.tags.isEmpty)
        #expect(!env.vm.isAddingTag)
    }

    @Test func существующее_имя_выбирает_тег_без_дубля() async {
        let fuel = TagModel.makeTest(name: "Бензин")
        let env = await makeEnv(tags: [fuel])
        env.vm.startAddingTag()
        env.vm.newTagName = "бензин"
        await env.vm.commitNewTag()
        #expect(env.tagRepo.tags.count == 1)
        #expect(env.vm.selectedTags.map(\.id) == [fuel.id])
    }

    @Test func имя_скрытого_тега_возвращает_его() async {
        let old = TagModel.makeTest(name: "Парковка", isArchived: true)
        let env = await makeEnv(tags: [old])
        env.vm.startAddingTag()
        env.vm.newTagName = "Парковка"
        await env.vm.commitNewTag()
        #expect(env.tagRepo.tags.count == 1)
        #expect(env.tagRepo.tags.first?.isArchived == false)
        #expect(env.vm.carouselTags.map(\.id) == [old.id])
    }

    @Test func переименование_меняет_имя() async {
        let fuel = TagModel.makeTest(name: "Бензин")
        let env = await makeEnv(tags: [fuel])
        env.vm.toggleTag(fuel)
        env.vm.beginRename(fuel)
        env.vm.renameText = "Топливо"
        await env.vm.commitRename()
        #expect(env.tagRepo.tags.first?.name == "Топливо")
        #expect(env.vm.selectedTags.first?.name == "Топливо")
        #expect(env.vm.tagBeingRenamed == nil)
    }

    @Test func переименование_в_занятое_имя_ошибка() async {
        let a = TagModel.makeTest(name: "Бензин")
        let b = TagModel.makeTest(name: "Мойка")
        let env = await makeEnv(tags: [a, b])
        env.vm.beginRename(b)
        env.vm.renameText = "БЕНЗИН"
        await env.vm.commitRename()
        #expect(env.vm.errorMessage != nil)
        #expect(env.tagRepo.tags.map(\.name) == ["Бензин", "Мойка"])
    }

    @Test func скрытие_убирает_из_карусели_и_снимает() async {
        let fuel = TagModel.makeTest(name: "Бензин")
        let env = await makeEnv(tags: [fuel])
        env.vm.toggleTag(fuel)
        await env.vm.hideTag(fuel)
        #expect(env.tagRepo.tags.first?.isArchived == true)
        #expect(env.vm.selectedTags.isEmpty)
        #expect(env.vm.carouselTags.isEmpty)
    }

    @Test func ошибка_репозитория_не_глотается() async {
        let env = await makeEnv()
        env.tagRepo.shouldThrow = true
        env.vm.startAddingTag()
        env.vm.newTagName = "Кофе"
        await env.vm.commitNewTag()
        #expect(env.vm.errorMessage != nil)
        #expect(env.vm.selectedTags.isEmpty)
    }

    @Test func редактирование_подставляет_оба_тега_импорта() async {
        let category = CategoryModel.makeTest(name: "Машина")
        let a = TagModel.makeTest(name: "Мойка")
        let b = TagModel.makeTest(name: "Каршер")
        let account = AccountModel.makeTest()
        let entry = EntryModel.makeTest(type: .expense, amount: 100, from: account, category: category, tags: [a, b])
        let env = await makeEnv(tags: [a, b], editing: entry)
        #expect(Set(env.vm.selectedTags.map(\.id)) == [a.id, b.id])
        // Тап по одному из двух снимает только его.
        env.vm.toggleTag(a)
        #expect(env.vm.selectedTags.map(\.id) == [b.id])
    }

    @Test func редактирование_со_скрытым_тегом_показывает_его_в_карусели() async {
        let category = CategoryModel.makeTest()
        let hidden = TagModel.makeTest(name: "Старый", isArchived: true)
        let entry = EntryModel.makeTest(type: .expense, amount: 100, from: AccountModel.makeTest(), category: category, tags: [hidden])
        let env = await makeEnv(tags: [hidden], editing: entry)
        #expect(env.vm.carouselTags.map(\.id) == [hidden.id])
        env.vm.toggleTag(hidden)
        #expect(env.vm.carouselTags.isEmpty)
    }

    @Test func сохранить_с_открытым_полем_ставит_новый_тег() async {
        let env = await makeEnv()
        env.vm.amountString = "200"
        env.vm.startAddingTag()
        env.vm.newTagName = "Кофе"
        await env.vm.save()
        #expect(env.entryRepo.savedEntry?.tags.map(\.name) == ["Кофе"])
        #expect(env.tagRepo.tags.map(\.name) == ["Кофе"])
    }
}
