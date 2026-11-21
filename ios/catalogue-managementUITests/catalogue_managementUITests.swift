import Foundation
import XCTest

final class catalogue_managementUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testSearchTabAcceptsAProductQuery() throws {
        let app = XCUIApplication()
        app.launch()

        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5))
        searchTab.tap()

        let searchField = app.textFields["catalogue.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("boots")

        XCTAssertEqual(searchField.value as? String, "boots")
    }

    @MainActor
    func testProductToEnquiryFlowAgainstLocalServices() async throws {
        guard await localBackendHasSearchData(), await localMailpitIsAvailable() else {
            throw XCTSkip("The local backend, Fake Store API, or Mailpit is unavailable.")
        }

        let app = XCUIApplication()
        app.launch()

        capture(app, named: "Home")
        let electronicsCategory = app.buttons["Electronics"]
        XCTAssertTrue(electronicsCategory.waitForExistence(timeout: 15))
        electronicsCategory.tap()
        XCTAssertTrue(app.staticTexts["Top rated"].waitForExistence(timeout: 15))
        capture(app, named: "Category-Featured")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["More to explore"].waitForExistence(timeout: 10))
        let remainingProduct = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Samsung 49-Inch")
        ).firstMatch
        XCTAssertTrue(remainingProduct.waitForExistence(timeout: 10))
        capture(app, named: "Category-Remaining")

        app.terminate()
        app.launch()
        app.tabBars.buttons["Search"].tap()

        let searchField = app.textFields["catalogue.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Mens Cotton Jacket")

        let productResult = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Mens Cotton Jacket")
        ).firstMatch
        XCTAssertTrue(productResult.waitForExistence(timeout: 20))
        capture(app, named: "Search")
        productResult.tap()

        let enquireButton = app.buttons["Enquire Now"]
        XCTAssertTrue(enquireButton.waitForExistence(timeout: 10))
        capture(app, named: "Product-Details")
        enquireButton.tap()

        let nameField = app.textFields["enquiry.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Local Integration Test")

        let emailField = app.textFields["enquiry.email"]
        emailField.tap()
        emailField.typeText("ios-integration@example.com")

        let messageField = app.textViews["enquiry.message"]
        messageField.tap()
        messageField.typeText("Please share more information. This is a local integration test.")
        capture(app, named: "Enquiry-Form")

        let submitButton = app.buttons["enquiry.submit"]
        submitButton.tap()

        let confirmation = app.descendants(matching: .any)
            .matching(identifier: "enquiry.thankYou")
            .firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 20))
        capture(app, named: "Thank-You")
    }


    @MainActor
    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func localMailpitIsAvailable() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:8025/api/v1/messages?limit=1") else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    @MainActor
    private func localBackendHasSearchData() async -> Bool {
        // This opt-in integration check targets the app's documented local simulator URL.
        guard let url = URL(string: "http://127.0.0.1:3000/api/v1/products/search?q=Mens%20Cotton%20Jacket") else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let body = String(data: data, encoding: .utf8)
            else { return false }
            return body.contains("Mens Cotton Jacket")
        } catch {
            return false
        }
    }
}
