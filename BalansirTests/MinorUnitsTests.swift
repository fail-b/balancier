import Testing
import Foundation
@testable import Balansir

/// Суммы в минимальных единицах (Core Data v4, задача 14).
@Suite("MinorUnits")
@MainActor
struct MinorUnitsTests {

    @Test func рубли_в_копейки_и_обратно() {
        #expect(MinorUnits.toMinor(Decimal(string: "311.06")!, currency: "RUB") == 31106)
        #expect(MinorUnits.fromMinor(31106, currency: "RUB") == Decimal(string: "311.06")!)
    }

    @Test func отрицательная_сумма() {
        #expect(MinorUnits.toMinor(Decimal(string: "-18400.5")!, currency: "RUB") == -1840050)
        #expect(MinorUnits.fromMinor(-1840050, currency: "RUB") == Decimal(string: "-18400.5")!)
    }

    @Test func знаки_валюты_по_ISO_4217() {
        #expect(MinorUnits.fractionDigits(for: "RUB") == 2)
        #expect(MinorUnits.fractionDigits(for: "JPY") == 0)
        #expect(MinorUnits.fractionDigits(for: "KWD") == 3)
        #expect(MinorUnits.toMinor(1500, currency: "JPY") == 1500)
        #expect(MinorUnits.toMinor(Decimal(string: "1.234")!, currency: "KWD") == 1234)
    }

    @Test func лишние_знаки_округляются() {
        #expect(MinorUnits.toMinor(Decimal(string: "10.005")!, currency: "RUB") == 1001)
        #expect(MinorUnits.toMinor(Decimal(string: "10.004")!, currency: "RUB") == 1000)
    }

    /// Double 311.06 хранится как 311.0599…: перенос старых значений не теряет копейку.
    @Test func старое_значение_Double_переносится_точно() {
        #expect(MinorUnits.toMinor(legacy: 311.06, currency: "RUB") == 31106)
        #expect(MinorUnits.toMinor(legacy: 0.29, currency: "RUB") == 29)
        #expect(MinorUnits.toMinor(legacy: -6419.7, currency: "RUB") == -641970)
        #expect(MinorUnits.toMinor(legacy: 170000, currency: "RUB") == 17000000)
    }
}
