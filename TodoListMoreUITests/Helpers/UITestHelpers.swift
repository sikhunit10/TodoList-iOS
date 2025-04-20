//
//  UITestHelpers.swift
//  TodoListMoreUITests
//
//  Created for TodoList-iOS.
//

import XCTest

/// Helper methods for UI testing
class UITestHelpers {
    
    // MARK: - App Navigation
    
    /// Navigate to the categories screen from any part of the app
    static func navigateToCategories(in app: XCUIApplication) {
        // Check if we can reach Categories directly from a tab
        if app.tabBars.buttons["Categories"].exists {
            app.tabBars.buttons["Categories"].tap()
        } else {
            // Try to access through settings
            app.tabBars.buttons["Settings"].tap()
            
            // Wait for settings screen to appear
            _ = waitForElement(app.navigationBars["Settings"])
            
            // Try different ways to find the Categories option
            if app.tables.cells["Categories"].exists {
                app.tables.cells["Categories"].tap()
            } else if app.buttons["Categories"].exists {
                app.buttons["Categories"].tap()
            } else if app.staticTexts["Categories"].exists {
                app.staticTexts["Categories"].tap()
            } else {
                // As a last resort, print all elements for debugging
                print("Available elements: \(app.descendants(matching: .any).allElementsBoundByIndex.map { $0.label })")
                XCTFail("Could not find Categories in the UI")
            }
        }
        
        // Verify we arrived at the right screen
        XCTAssertTrue(waitForElement(app.navigationBars["Categories"]))
    }
    
    // MARK: - Wait Helpers
    
    /// Wait for a condition to be true with timeout
    static func wait(for condition: @escaping () -> Bool, timeout: TimeInterval = 5, description: String) -> Bool {
        let start = Date()
        
        while !condition() {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("Timed out waiting for condition: \(description)")
                return false
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        
        return true
    }
    
    /// Wait for an element to exist
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return wait(for: { element.exists }, timeout: timeout, description: "Waiting for element to exist")
    }
    
    // MARK: - Cleanup Helpers
    
    /// Delete all categories in the categories screen
    static func deleteAllCategories(in app: XCUIApplication) {
        // Make sure we're on the categories screen
        navigateToCategories(in: app)
        
        // If there are no categories, return early
        if app.staticTexts["No Categories Found"].exists {
            return
        }
        
        // Enter edit mode
        app.navigationBars["Categories"].buttons["pencil"].tap()
        
        // Select all and delete
        if app.buttons["Select All"].exists {
            app.buttons["Select All"].tap()
            
            if app.buttons["Delete"].isEnabled {
                app.buttons["Delete"].tap()
            }
        }
        
        // Exit edit mode if still in it
        if app.navigationBars["Categories"].buttons["checkmark"].exists {
            app.navigationBars["Categories"].buttons["checkmark"].tap()
        }
    }
    
    // MARK: - Common Actions
    
    /// Create a new category with the given name and color
    static func createCategory(named name: String, colorIndex: Int = 0, in app: XCUIApplication) {
        // Make sure we're on the categories screen
        navigateToCategories(in: app)
        
        // Tap add button
        app.navigationBars["Categories"].buttons["plus"].tap()
        
        // Enter name
        let nameField = app.textFields["Name"]
        nameField.tap()
        nameField.typeText(name)
        
        // Select color if specified
        if colorIndex > 0 && colorIndex < 4 {
            app.scrollViews.otherElements.buttons.element(boundBy: colorIndex).tap()
        }
        
        // Save
        app.navigationBars["New Category"].buttons["Save"].tap()
    }
}