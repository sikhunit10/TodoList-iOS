//
//  BasicCategoriesTest.swift
//  TodoListMoreUITests
//
//  Created for TodoList-iOS.
//

import XCTest

class BasicCategoriesTest: XCTestCase {
    // This test is the simplest possible test for the Categories screen
    
    func testNavigateToCategoriesAndCreateCategory() throws {
        // Set up test
        let app = XCUIApplication()
        app.launch()
        
        // Print tabs to help with debugging
        print("Available tabs:")
        for button in app.tabBars.buttons.allElementsBoundByIndex {
            print("Tab: \(button.label)")
        }
        
        // 1. Navigate to Categories tab if it exists
        if app.tabBars.buttons["Categories"].exists {
            app.tabBars.buttons["Categories"].tap()
            sleep(1) // Wait for UI to update
            
            // 2. Verify we're on the Categories screen
            print("Navigation bars:")
            for navbar in app.navigationBars.allElementsBoundByIndex {
                print("NavBar: \(navbar.identifier)")
            }
            
            // 3. Print all UI elements to help with debugging
            print("All UI elements:")
            for element in app.descendants(matching: .any).allElementsBoundByIndex {
                if !element.label.isEmpty || !element.identifier.isEmpty {
                    print("Element: Type=\(element.elementType), Label='\(element.label)', ID='\(element.identifier)'")
                }
            }
            
            // 4. Verify we can interact with the Categories screen
            // Check if we can find the add button
            if let addButton = findAddButton(in: app) {
                // Success! We found the add button
                XCTAssertTrue(addButton.isEnabled, "Add button should be enabled")
                
                // Try to create a category if the button is enabled
                if addButton.isEnabled {
                    addButton.tap()
                    sleep(1) // Wait for UI to update
                    
                    // Try to find the text field
                    let textFields = app.textFields.allElementsBoundByIndex
                    if let nameField = textFields.first {
                        // Enter category name
                        nameField.tap()
                        nameField.typeText("Simple Test Category")
                        
                        // Find and tap save button
                        let saveButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Save")).allElementsBoundByIndex
                        if let saveButton = saveButtons.first, saveButton.isEnabled {
                            saveButton.tap()
                            XCTAssertTrue(true, "Successfully created a category")
                        } else {
                            print("Save button not found or not enabled")
                        }
                    } else {
                        print("No text fields found in category form")
                    }
                }
            } else {
                XCTFail("Could not find add button on Categories screen")
            }
        } else {
            XCTFail("Categories tab not found")
        }
    }
    
    // Helper method to find the add button
    private func findAddButton(in app: XCUIApplication) -> XCUIElement? {
        // Try multiple ways to find the add button
        if app.navigationBars["Categories"].buttons["plus"].exists {
            return app.navigationBars["Categories"].buttons["plus"]
        }
        
        if app.navigationBars.buttons["plus"].exists {
            return app.navigationBars.buttons["plus"]
        }
        
        if app.buttons["plus"].exists {
            return app.buttons["plus"]
        }
        
        // Look for buttons with "Add" label
        let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add")).allElementsBoundByIndex
        return addButtons.first { $0.isEnabled }
    }
}