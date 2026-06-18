//
//  HoldApp_iOSUITests.swift
//  HoldApp-iOSUITests
//
//  Created by Vishal Jain on 04/11/2025.
//

import XCTest

final class HoldApp_iOSUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testFirstRunMacConnectionHelp() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Connect your Mac"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Hold is designed to capture tasks on your Mac and display them on your phone. Connect your Mac to complete the experience:"].exists)
        XCTAssertTrue(app.staticTexts["Open this link on your Mac (ensure it's signed into the same iCloud account as this iPhone)."].exists)
        XCTAssertTrue(app.staticTexts["Download Hold."].exists)
        XCTAssertTrue(app.staticTexts["Enter a new task and watch it show up on your phone!"].exists)
        XCTAssertTrue(app.buttons["Share or Copy Link"].exists)

        app.buttons["Close"].tap()

        XCTAssertTrue(app.staticTexts["what are you holding?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Mac not connected. Setup instructions."].exists)

        app.buttons["Mac not connected. Setup instructions."].tap()
        XCTAssertTrue(app.staticTexts["Connect your Mac"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
