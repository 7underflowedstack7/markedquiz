import XCTest

final class MarkedQuizUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Test 1: Tab Navigation
    
    /// Tests that the user can successfully navigate between all three tabs
    /// in the main TabView: Library, Database, and Stats
    func testTabNavigation() throws {
        // Verify the app launched and Library tab is initially selected
        let libraryTab = app.tabBars.buttons["Library"]
        let databaseTab = app.tabBars.buttons["Database"]
        let statsTab = app.tabBars.buttons["Stats"]
        
        // Library tab should be selected by default (tab 0)
        XCTAssertTrue(libraryTab.exists, "Library tab should exist")
        
        // Navigate to Database tab
        databaseTab.tap()
        
        // Verify Database view is displayed by checking for the navigation title
        let databaseTitle = app.staticTexts["DATABASE"]
        XCTAssertTrue(databaseTitle.waitForExistence(timeout: 2), "Database title should be visible after tapping Database tab")
        
        // Verify Database view content (either loading, error, or document list)
        let databaseViewExists = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'POSTGRESQL' OR label CONTAINS[c] 'NO FILES' OR label CONTAINS[c] 'Loading'")).firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(databaseViewExists, "Database view content should be visible")
        
        // Navigate to Stats tab
        statsTab.tap()
        
        // Verify Stats view is displayed
        let statsViewExists = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Stats' OR label CONTAINS[c] 'XP' OR label CONTAINS[c] 'QUIZZES'")).firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(statsViewExists, "Stats view content should be visible after tapping Stats tab")
        
        // Navigate back to Library tab
        libraryTab.tap()
        
        // Verify Library view is displayed again
        let libraryTitle = app.staticTexts["MARKED//QUIZ"]
        XCTAssertTrue(libraryTitle.waitForExistence(timeout: 2), "Library title should be visible after tapping Library tab")
    }
    
    // MARK: - Test 2: Library View Document Addition Flow
    
    /// Tests the document addition flow in the Library view,
    /// verifying that the add button opens the sheet and displays the correct options
    func testLibraryAddDocumentSheet() throws {
        // Wait for the Library view to load
        let libraryTitle = app.staticTexts["MARKED//QUIZ"]
        XCTAssertTrue(libraryTitle.waitForExistence(timeout: 5), "Library should be visible on launch")
        
        // Find and tap the add button in the toolbar
        let addButton = app.buttons["Add document"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2), "Add document button should exist in the toolbar")
        addButton.tap()
        
        // Verify the add document sheet is presented
        // The sheet should contain options for creating a document
        let sheetExists = app.otherElements["Add Document Sheet"].waitForExistence(timeout: 2) ||
                         app.sheets.firstMatch.waitForExistence(timeout: 2)
        XCTAssertTrue(sheetExists, "Add document sheet should be presented")
        
        // Check for typical sheet elements (title field, content field, or file picker options)
        // These might vary based on your exact implementation, but let's check for common elements
        let hasTextField = app.textFields.firstMatch.waitForExistence(timeout: 1)
        let hasButton = app.buttons.count > 0
        
        XCTAssertTrue(hasTextField || hasButton, "Sheet should contain interactive elements (text fields or buttons)")
        
        // If there's a cancel/close button, tap it to dismiss
        let cancelButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Cancel' OR label CONTAINS[c] 'Close' OR label CONTAINS[c] 'Dismiss'")).firstMatch
        if cancelButton.exists {
            cancelButton.tap()
            
            // Verify the sheet is dismissed and we're back to the library view
            XCTAssertTrue(libraryTitle.exists, "Should return to Library view after dismissing sheet")
        }
    }
    
    // MARK: - Bonus Helper Test: Empty State Verification
    
    /// Tests that the empty state is properly displayed when no documents exist
    func testLibraryEmptyState() throws {
        // Wait for initial load
        sleep(2)
        
        // Check if empty state is visible (when no documents are present)
        let emptyStateTitle = app.staticTexts["NO DOCUMENTS"]
        let emptyStateMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Upload a markdown file'")).firstMatch
        let emptyStateAction = app.buttons["ADD DOCUMENT"]
        
        // If documents don't exist, verify empty state
        if emptyStateTitle.waitForExistence(timeout: 3) {
            XCTAssertTrue(emptyStateMessage.exists, "Empty state message should be visible")
            XCTAssertTrue(emptyStateAction.exists, "Empty state action button should be visible")
            
            // Test that the action button opens the add sheet
            emptyStateAction.tap()
            
            let sheetAppeared = app.sheets.firstMatch.waitForExistence(timeout: 2)
            XCTAssertTrue(sheetAppeared, "Tapping empty state action should open the add document sheet")
        } else {
            // Documents exist, verify document list is shown instead
            let hasDocuments = app.scrollViews.firstMatch.exists
            XCTAssertTrue(hasDocuments, "Document list should be visible when documents exist")
        }
    }
}
