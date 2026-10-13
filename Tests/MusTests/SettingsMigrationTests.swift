import XCTest
import MouseCore
@testable import Mus

final class SettingsMigrationTests: XCTestCase {
    func testRenameMigratesMouseScrollAndLanguageWithoutOverwritingMusPreferences() throws {
        let names = (0..<3).map { "local.mus.tests.migration.\(UUID().uuidString).\($0)" }
        let stores = try names.map { try XCTUnwrap(UserDefaults(suiteName: $0)) }
        defer {
            for (store, name) in zip(stores, names) { store.removePersistentDomain(forName: name) }
            L10n.language = .system
        }
        var saved = MouseSettings()
        saved.front = ButtonBinding(button: 6, action: .desktopLeft)
        saved.reverseVertical = true
        saved.scroll.enabled = true
        saved.scroll.speed = 0.75
        stores[1].set(try JSONEncoder().encode(saved), forKey: "mouseSettings.v1")
        stores[1].set("en", forKey: "interfaceLanguage")
        stores[2].set(try JSONEncoder().encode(MouseSettings()), forKey: "mouseSettings.v1")
        let first = AppModel(defaults: stores[0], legacyDefaults: [stores[1], stores[2]])
        XCTAssertEqual(first.settings, saved)
        XCTAssertEqual(first.language, .english)
        first.settings.scroll.speed = 1.5
        first.language = .chinese
        let second = AppModel(defaults: stores[0], legacyDefaults: [stores[1], stores[2]])
        XCTAssertEqual(second.settings.scroll.speed, 1.5)
        XCTAssertEqual(second.settings.front.button, 6)
        XCTAssertEqual(second.language, .chinese)
        XCTAssertEqual(stores[1].string(forKey: "interfaceLanguage"), "en")
    }
    func testInvalidLegacySettingsFallBackToEarlierValidPreferences() throws {
        let names = (0..<3).map { "local.mus.tests.migration.\(UUID().uuidString).\($0)" }
        let stores = try names.map { try XCTUnwrap(UserDefaults(suiteName: $0)) }
        defer {
            for (store, name) in zip(stores, names) { store.removePersistentDomain(forName: name) }
            L10n.language = .system
        }
        stores[1].set(Data("broken".utf8), forKey: "mouseSettings.v1")
        var old = MouseSettings(); old.reverseHorizontal = true
        stores[2].set(try JSONEncoder().encode(old), forKey: "mouseSettings.v1")
        XCTAssertEqual(AppModel(defaults: stores[0], legacyDefaults: [stores[1], stores[2]]).settings, old)
    }
}
