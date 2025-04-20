//
//  CategoryUITests.swift
//  TodoListMoreUITests
//
//  Created for TodoList-iOS.
//

import XCTest

class CategoryUITests: TestBase {
    
    override var launchArguments: [String] {
        return ["--ui-testing", "--direct-to-categories"]
    }
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Print UI hierarchy to help debug navigation
        printUIHierarchy()
        
        // Check if we're already on the Categories screen
        if !app.navigationBars["Categories"].exists {
            // If not, try navigating there
            navigateToCategories()
            
            // Print UI again after navigation
            print("*** UI AFTER NAVIGATION ***")
            printUIHierarchy()
        }
    }
    
    override func tearDownWithError() throws {
        // Clean up by deleting any test categories we might have created
        deleteAllTestCategories()
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    private func navigateToCategories() {
        // Check if we can reach Categories directly from a tab
        if app.tabBars.buttons["Categories"].exists {
            app.tabBars.buttons["Categories"].tap()
            return
        }
        
        // Try to access through settings
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
            
            // Print available table cells for debugging
            print("Available table cells: \(app.tables.cells.allElementsBoundByIndex.map { $0.identifier })")
            
            // Try to find Categories in different ways
            if app.tables.cells["Categories"].exists {
                app.tables.cells["Categories"].tap()
            } else if app.buttons["Categories"].exists {
                app.buttons["Categories"].tap()
            } else if app.staticTexts["Categories"].exists {
                app.staticTexts["Categories"].tap()
            } else {
                // Log all visible elements to help debug
                let elements = app.descendants(matching: .any)
                print("All visible elements: \(elements.allElementsBoundByIndex.map { $0.identifier })")
                XCTFail("Could not find Categories in the UI")
            }
        } else {
            XCTFail("Could not find Settings tab")
        }
    }
    
    private func deleteAllTestCategories() {
        // Make sure we're on the Categories screen
        if !app.navigationBars["Categories"].exists {
            navigateToCategories()
        }
        
        // Skip if there's an empty state already
        if app.staticTexts["No Categories Found"].exists {
            return
        }
        
        // Enter edit mode - handle possible failure
        if app.navigationBars["Categories"].buttons["pencil"].exists {
            if app.navigationBars["Categories"].buttons["pencil"].isEnabled {
                app.navigationBars["Categories"].buttons["pencil"].tap()
                
                // Give UI time to update
                sleep(1)
                
                // Select all categories if the button exists
                if app.buttons["Select All"].exists {
                    app.buttons["Select All"].tap()
                    
                    // Delete all categories if possible
                    if app.buttons["Delete"].exists && app.buttons["Delete"].isEnabled {
                        app.buttons["Delete"].tap()
                    }
                }
                
                // Exit edit mode if still in it
                if app.navigationBars["Categories"].buttons["checkmark"].exists {
                    app.navigationBars["Categories"].buttons["checkmark"].tap()
                }
            }
        }
        
        // Give the UI time to update
        sleep(1)
    }
    
    private func createTestCategory(name: String, colorIndex: Int = 0) {
        // Wait for UI to be ready
        XCTAssertTrue(waitForElement(app.navigationBars["Categories"]), "Categories navigation bar not found")
        
        // Tap on + button (trying multiple ways)
        if app.navigationBars["Categories"].buttons["plus"].exists {
            app.navigationBars["Categories"].buttons["plus"].tap()
        } else if app.navigationBars.buttons["plus"].exists {
            app.navigationBars.buttons["plus"].tap()
        } else if app.buttons["plus"].exists {
            app.buttons["plus"].tap()
        } else {
            // Try looking for buttons with "Add" label
            let addButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add")).allElementsBoundByIndex
            if let addButton = addButtons.first(where: { $0.isEnabled }) {
                addButton.tap()
            } else {
                XCTFail("Could not find add button")
                return
            }
        }
        
        // Wait for form to appear
        sleep(1)
        
        // Enter category name (trying multiple ways)
        let nameTextField = app.textFields["Name"].firstMatch
        if nameTextField.exists {
            nameTextField.tap()
            nameTextField.typeText(name)
        } else {
            // Try finding the first text field
            let textFields = app.textFields.allElementsBoundByIndex
            if !textFields.isEmpty {
                let firstTextField = textFields[0]
                firstTextField.tap()
                firstTextField.typeText(name)
            } else {
                XCTFail("Could not find any text field")
                return
            }
        }
        
        // Select color if not the default one (default is index 0)
        if colorIndex > 0 {
            // Use accessibility identifier set in the app: "CategoryColor_<index>"
            let colorButtonIdentifier = "CategoryColor_\(colorIndex)"
            let colorButton = app.buttons[colorButtonIdentifier]
            if colorButton.exists {
                colorButton.tap()
            } else {
                XCTFail("Could not find color button '\(colorButtonIdentifier)' for colorIndex=\(colorIndex)")
            }
        }
        
        // Save category (try multiple ways)
        if app.navigationBars["New Category"].buttons["Save"].exists {
            app.navigationBars["New Category"].buttons["Save"].tap()
        } else if app.buttons["Save"].exists {
            app.buttons["Save"].tap()
        } else {
            // Try to find any Save button
            let saveButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Save")).allElementsBoundByIndex
            if let saveButton = saveButtons.first {
                saveButton.tap()
            } else {
                XCTFail("Could not find save button")
                return
            }
        }
        
        // Wait for save operation to complete
        sleep(1)
    }
    
    // MARK: - Test Cases
    
    /// Tests that the category list screen displays correctly
    func testCategoryListDisplays() throws {
        // Check if we're on the categories screen
        XCTAssertTrue(app.navigationBars["Categories"].exists)
        
        // Check for the presence of the Add button
        XCTAssertTrue(app.navigationBars["Categories"].buttons["plus"].exists)
        
        // Check for the presence of the Edit button
        XCTAssertTrue(app.navigationBars["Categories"].buttons["pencil"].exists)
    }
    
    /// Tests creating a new category
    func testCreateCategory() throws {
        let testCategoryName = "Test Category"
        
        // Print UI elements before creating category
        print("Before creating category:")
        printUIHierarchy()
        
        // Count cells before creating category
        let initialCellElements = app.descendants(matching: .cell).allElementsBoundByIndex
        let initialCount = initialCellElements.count
        print("Initial cell count: \(initialCount)")
        
        // Create category
        createTestCategory(name: testCategoryName)
        
        // Wait for UI to update
        sleep(1)
        
        // Print UI elements after creating category
        print("After creating category:")
        printUIHierarchy()
        
        // Try different ways to find the created category
        let textExists = waitForElement(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", testCategoryName)).firstMatch, timeout: 3)
        
        // If direct text verification failed, check if number of cells increased
        if !textExists {
            let newCellElements = app.descendants(matching: .cell).allElementsBoundByIndex
            let newCount = newCellElements.count
            print("New cell count: \(newCount)")
            
            // Print cells for debugging
            for (index, cell) in newCellElements.enumerated() {
                print("Cell \(index): \(cell.debugDescription)")
                let texts = cell.descendants(matching: .staticText).allElementsBoundByIndex
                for text in texts {
                    print("  - Text: \(text.label)")
                }
            }
            
            // Either the static text should exist OR the cell count should have increased
            XCTAssertTrue(textExists || newCount > initialCount, 
                          "Category wasn't created or couldn't be found")
        } else {
            XCTAssertTrue(true, "Found category text")
        }
    }
    
    // MARK: - Create with All Colors
    /// Tests creating categories with all available colors
    func testCreateCategoryWithAllColors() throws {
        let colors = ["Blue", "Green", "Orange", "Red"]
        for (index, colorName) in colors.enumerated() {
            let categoryName = "Color \(colorName)"
            createTestCategory(name: categoryName, colorIndex: index)
            XCTAssertTrue(app.staticTexts[categoryName].waitForExistence(timeout: 5),
                          "Category '\(categoryName)' should be visible after saving")
        }
    }
    
    
    /// Tests that creating a category with an empty name is not allowed
    func testCreateCategoryWithEmptyName() throws {
        // Initial count
        let initialCategoryCount = app.cells.count
        
        // Tap on + button
        app.navigationBars["Categories"].buttons["plus"].tap()
        
        // Leave name field empty
        
        // Verify Save button is disabled
        XCTAssertFalse(app.navigationBars["New Category"].buttons["Save"].isEnabled)
        
        // Cancel creation
        app.navigationBars["New Category"].buttons["Cancel"].tap()
        
        // Verify no category was created
        XCTAssertEqual(app.cells.count, initialCategoryCount)
    }
    
    /// Tests editing an existing category
    func testEditCategory() throws {
        // Create test category
        let testCategoryName = "Edit Test"
        createTestCategory(name: testCategoryName)
        
        // Verify category exists
        XCTAssertTrue(app.staticTexts[testCategoryName].exists)
        
        // Tap on the category to edit
        app.staticTexts[testCategoryName].tap()
        
        // Edit the category name
        let updatedName = "Edited Category"
        let nameTextField = app.textFields["Name"]
        nameTextField.tap()
        // Clear existing text by sending delete keystrokes
        if let existingValue = nameTextField.value as? String {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existingValue.count)
            nameTextField.typeText(deleteString)
        }
        nameTextField.typeText(updatedName)
        
        // Change color (select second color, index 1)
        let editColorButton = app.buttons["CategoryColor_1"]
        XCTAssertTrue(editColorButton.exists, "Edit color button 'CategoryColor_1' should exist")
        editColorButton.tap()
        
        // Save changes
        app.navigationBars["Edit Category"].buttons["Save"].tap()
        
        // Verify category was updated
        XCTAssertTrue(app.staticTexts[updatedName].exists)
        XCTAssertFalse(app.staticTexts[testCategoryName].exists)
    }
    
    /// Tests deleting a category using swipe action
    func testDeleteCategorySwipe() throws {
        // Create test category
        let testCategoryName = "Swipe Delete Test"
        createTestCategory(name: testCategoryName)
        
        // Verify category exists
        XCTAssertTrue(app.staticTexts[testCategoryName].exists)
        
        // Initial count of categories
        let initialCategoryCount = app.cells.count

        // Swipe to delete the category
        let cell = app.staticTexts[testCategoryName]
        XCTAssertTrue(cell.exists, "Category '\(testCategoryName)' cell should exist before deletion")
        cell.swipeLeft()
        
        // Tap the Delete action
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button should appear after swipe")
        deleteButton.tap()

        // Wait for the category cell to disappear
        let doesNotExist = NSPredicate(format: "exists == false")
        expectation(for: doesNotExist, evaluatedWith: cell, handler: nil)
        waitForExpectations(timeout: 5)

        // Verify the category text is gone
        XCTAssertFalse(cell.exists,
                       "Category '\(testCategoryName)' should not exist after deletion")
        XCTAssertFalse(app.staticTexts[testCategoryName].exists)
    }
    
    /// Tests deleting a category using edit mode
    func testDeleteCategoryEditMode() throws {
        // Create test category
        let testCategoryName = "Edit Delete Test"
        createTestCategory(name: testCategoryName)
        
        // Verify category exists
        XCTAssertTrue(app.staticTexts[testCategoryName].exists)
        
        // Initial count of category cells
        let initialCategoryCount = app.cells.count
        
        // Enter edit mode
        app.navigationBars["Categories"].buttons["pencil"].tap()
        
        // Select the category
        app.staticTexts[testCategoryName].tap()
        
        // Delete selected category
        app.buttons["Delete"].tap()
        
        // Exit edit mode
        app.navigationBars["Categories"].buttons["checkmark"].tap()
        
        // Verify category was deleted
        XCTAssertEqual(app.cells.count, initialCategoryCount - 1)
        XCTAssertFalse(app.staticTexts[testCategoryName].exists)
    }
    
    /// Tests deleting multiple categories at once
    func testDeleteMultipleCategories() throws {
        // Create test categories
        let testNames = ["Multi Delete 1", "Multi Delete 2", "Multi Delete 3"]
        for name in testNames {
            createTestCategory(name: name)
        }
        
        // Verify categories exist
        for name in testNames {
            XCTAssertTrue(app.staticTexts[name].exists)
        }
        
        // Initial count
        let initialCategoryCount = app.cells.count
        
        // Enter edit mode
        app.navigationBars["Categories"].buttons["pencil"].tap()
        
        // Select all categories
        app.buttons["Select All"].tap()
        
        // Delete selected categories
        app.buttons["Delete"].tap()
        
        // Exit edit mode automatically happens if no categories left
        
        // Verify all test categories were deleted
        for name in testNames {
            XCTAssertFalse(app.staticTexts[name].exists)
        }
        
        // Verify correct number of categories remain
        XCTAssertEqual(app.cells.count, initialCategoryCount - testNames.count)
    }
    
    /// Tests the search functionality
    func testSearchCategory() throws {
        // Create test categories with distinct names
        let testNames = ["Apple Category", "Banana Category", "Cherry Category"]
        for name in testNames {
            createTestCategory(name: name)
        }
        
        // Use search bar
        let searchField = app.searchFields["Search categories"]
        searchField.tap()
        searchField.typeText("Ban")
        
        // Verify only matching category appears
        XCTAssertTrue(app.staticTexts["Banana Category"].exists)
        XCTAssertFalse(app.staticTexts["Apple Category"].exists)
        XCTAssertFalse(app.staticTexts["Cherry Category"].exists)
        
        // Clear search
        searchField.buttons["Clear text"].tap()
        app.buttons["Cancel"].tap()
        
        // Verify all categories appear again
        for name in testNames {
            XCTAssertTrue(app.staticTexts[name].exists)
        }
    }
    
    /// Tests that the edit mode UI elements appear correctly
    func testEditModeUI() throws {
        // Create a test category
        createTestCategory(name: "Edit Mode Test")
        
        // Enter edit mode
        app.navigationBars["Categories"].buttons["pencil"].tap()
        
        // Verify edit mode UI elements are present
        XCTAssertTrue(app.buttons["Select All"].exists)
        XCTAssertTrue(app.buttons["Delete"].exists)
        XCTAssertTrue(app.navigationBars["Categories"].buttons["checkmark"].exists)
        
        // Verify add button is disabled in edit mode
        XCTAssertFalse(app.navigationBars["Categories"].buttons["plus"].isEnabled)
        
        // Exit edit mode
        app.navigationBars["Categories"].buttons["checkmark"].tap()
        
        // Verify edit mode UI elements are gone
        XCTAssertFalse(app.buttons["Select All"].exists)
        XCTAssertFalse(app.buttons["Delete"].isHittable)
        XCTAssertTrue(app.navigationBars["Categories"].buttons["pencil"].exists)
        
        // Verify add button is enabled outside edit mode
        XCTAssertTrue(app.navigationBars["Categories"].buttons["plus"].isEnabled)
    }
    
    
    /// Tests the empty state (no categories)
    func testEmptyState() throws {
        // Delete all existing categories first
        deleteAllTestCategories()
        
        // Verify empty state elements
        XCTAssertTrue(app.staticTexts["No Categories Found"].exists)
        XCTAssertTrue(app.staticTexts["Categories help you organize your tasks more efficiently."].exists)
        XCTAssertTrue(app.buttons["Create Category"].exists)
        
        // Verify edit button is disabled when empty
        XCTAssertFalse(app.navigationBars["Categories"].buttons["pencil"].isEnabled)
        
        // Test creating a category from empty state
        app.buttons["Create Category"].tap()
        
        // Enter category name
        let nameTextField = app.textFields["Name"]
        nameTextField.tap()
        nameTextField.typeText("Empty State Test")
        
        // Save category
        app.navigationBars["New Category"].buttons["Save"].tap()
        
        // Verify category was created and empty state is gone
        XCTAssertTrue(app.staticTexts["Empty State Test"].exists)
        XCTAssertFalse(app.staticTexts["No Categories Found"].exists)
        XCTAssertTrue(app.navigationBars["Categories"].buttons["pencil"].isEnabled)
    }
    
    /// Tests the loading state (placeholder)
    func testLoadingState() throws {
        // Note: This is hard to test reliably since the loading state is usually very brief
        // This test is more of a placeholder for a potential implementation
        
        // One approach would be to modify the app for testing to artificially delay loading
        // For now, we'll just verify the app doesn't crash during initial load
        XCTAssertTrue(app.navigationBars["Categories"].exists)
    }
}
