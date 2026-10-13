import XCTest
import MouseCore
@testable import Mus

final class LocalizationTests: XCTestCase {
    override func tearDown() {
        L10n.language = .system
        super.tearDown()
    }

    func testLanguageSwitchChangesMenuAndActionTitles() {
        L10n.language = .english
        XCTAssertEqual(L10n.text("偏好设置…"), "Preferences…")
        XCTAssertEqual(L10n.text(ButtonAction.copy.title), "Copy  ⌘C")
        L10n.language = .chinese
        XCTAssertEqual(L10n.text("偏好设置…"), "偏好设置…")
        XCTAssertEqual(L10n.text(ButtonAction.copy.title), "复制  ⌘C")
    }

    func testFormattedMessagesKeepButtonNumbers() {
        L10n.language = .english
        XCTAssertEqual(L10n.format("已识别 %@ · 按键 %lld", L10n.text("后侧键"), Int64(4)),
                       "Identified Rear button · Button 4")
        L10n.language = .chinese
        XCTAssertEqual(L10n.format("已识别 %@ · 按键 %lld", L10n.text("后侧键"), Int64(4)),
                       "已识别 后侧键 · 按键 4")
    }

    func testBothLanguageResourcesContainTheSameKeysAndFormats() throws {
        func strings(_ language: String) throws -> [String: String] {
            let url = try XCTUnwrap(AppResources.bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language))
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        }
        let english = try strings("en")
        let chinese = try strings("zh-Hans")
        XCTAssertGreaterThan(english.count, 90)
        XCTAssertEqual(Set(english.keys), Set(chinese.keys))
        let format = try NSRegularExpression(pattern: "%(@|lld|d)")
        func placeholders(_ text: String) -> [String] {
            format.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                String(text[Range($0.range, in: text)!])
            }
        }
        for (key, value) in english {
            XCTAssertFalse(value.isEmpty, key)
            XCTAssertEqual(placeholders(value), placeholders(chinese[key]!), key)
        }
    }

    func testSelectedLanguageSurvivesRelaunchWithoutChangingMouseSettings() throws {
        let suite = "local.mus.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var settings = MouseSettings()
        settings.reverseVertical = true
        defaults.set(try JSONEncoder().encode(settings), forKey: "mouseSettings.v1")
        let model = AppModel(defaults: defaults)
        model.language = .english
        let restored = AppModel(defaults: defaults)
        XCTAssertEqual(restored.language, .english)
        XCTAssertEqual(restored.settings, settings)
        XCTAssertEqual(L10n.text("偏好设置…"), "Preferences…")
    }
}
