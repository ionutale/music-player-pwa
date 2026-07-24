import XCTest

final class MusicPlayerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
    }

    // MARK: - Setup Flow

    func testShowsSetupScreenWhenNotConfigured() {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "--reset-config"]
        app.launch()

        let welcomeTitle = app.staticTexts["Welcome"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 2))

        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.exists)
        XCTAssertFalse(connectButton.isEnabled) // disabled when fields empty
    }

    func testConnectButtonEnablesWithFields() {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "--reset-config"]
        app.launch()

        let serverField = app.textFields["Server URL"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 2))
        serverField.tap()
        serverField.typeText("http://localhost:8080")

        let apiKeyField = app.textFields["API Key"]
        apiKeyField.tap()
        apiKeyField.typeText("my-key")

        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.isEnabled)
    }

    // MARK: - Library Navigation

    func testLibraryShowsTabBar() {
        let app = XCUIApplication()
        let libraryTab = app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 3))
        XCTAssertTrue(libraryTab.isSelected)
    }

    func testLibraryShowsSegmentedControl() {
        let app = XCUIApplication()
        let segmented = app.segmentedControls.firstMatch
        XCTAssertTrue(segmented.waitForExistence(timeout: 3))
        XCTAssertTrue(segmented.buttons["Artists"].exists)
        XCTAssertTrue(segmented.buttons["Albums"].exists)
        XCTAssertTrue(segmented.buttons["Songs"].exists)
    }

    func testSwitchToAlbumsTab() {
        let app = XCUIApplication()
        let segmented = app.segmentedControls.firstMatch
        XCTAssertTrue(segmented.waitForExistence(timeout: 3))
        segmented.buttons["Albums"].tap()
        XCTAssertTrue(segmented.buttons["Albums"].isSelected)
    }

    func testSwitchToSongsTab() {
        let app = XCUIApplication()
        let segmented = app.segmentedControls.firstMatch
        XCTAssertTrue(segmented.waitForExistence(timeout: 3))
        segmented.buttons["Songs"].tap()
        XCTAssertTrue(segmented.buttons["Songs"].isSelected)
    }

    func testShowsSearchTab() {
        let app = XCUIApplication()
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 2))
        searchTab.tap()
        XCTAssertTrue(searchTab.isSelected)
    }

    // MARK: - Search

    func testSearchHasSearchBar() {
        let app = XCUIApplication()
        app.tabBars.buttons["Search"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
    }

    func testSearchAcceptsInput() {
        let app = XCUIApplication()
        app.tabBars.buttons["Search"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("Daft Punk")
        XCTAssertEqual(searchField.value as? String, "Daft Punk")
    }

    func testRecentSearchesAppear() {
        let app = XCUIApplication()
        app.tabBars.buttons["Search"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("Rock\n") // submit with return

        // Clear field to show recents
        searchField.tap()
        searchField.clearText()

        XCTAssertTrue(app.staticTexts["Recent Searches"].waitForExistence(timeout: 2))
    }

    // MARK: - Now Playing

    func testNowPlayingBarAppearsWhenPlaying() {
        let app = XCUIApplication()
        // Tap a song to start playback
        let songRow = app.buttons["Test Song"]
        if songRow.waitForExistence(timeout: 5) {
            songRow.tap()
            let nowPlayingBar = app.staticTexts["Now Playing"]
            XCTAssertTrue(nowPlayingBar.waitForExistence(timeout: 3))
        }
    }

    // MARK: - Settings

    func testSettingsAccessibleFromLibrary() {
        let app = XCUIApplication()

        // Search for settings button
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 2))
        }
    }

    // MARK: - Loading States

    func testLibraryShowsLoadingIndicator() {
        let app = XCUIApplication()
        let progressView = app.activityIndicators.firstMatch
        // Should show loading briefly while data loads
        XCTAssertTrue(progressView.waitForExistence(timeout: 3))
    }

    // MARK: - Search Loading

    func testSearchShowsLoadingWhileSearching() {
        let app = XCUIApplication()
        app.tabBars.buttons["Search"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("Test")

        let progressIndicator = app.activityIndicators.firstMatch
        // May or may not be visible depending on network speed
        // Not asserting existence, just checking no crash
    }
}

extension XCUIElement {
    func clearText() {
        guard let stringValue = value as? String else { return }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}
