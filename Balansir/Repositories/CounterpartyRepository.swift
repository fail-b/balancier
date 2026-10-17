import Foundation

protocol CounterpartyRepository {
    /// Все контрагенты, **включая удалённых** (мягко): по ним VM находит контрагента с тем же именем
    /// и возвращает его вместо создания дубля. Что показывать — решает VM.
    func fetchAll() async throws -> [CounterpartyModel]
    /// Создать или обновить (переименовать, сменить цвет/иконку, вернуть удалённого).
    func save(_ counterparty: CounterpartyModel) async throws
    /// Мягкое удаление: контрагент пропадает из списков, операции с ним остаются.
    func archive(_ id: UUID) async throws
}
