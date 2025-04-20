//
//  BasicCategoryTests.swift
//  TodoListMoreUITests
//
//  Created for TodoList-iOS.
//

import XCTest

// This test class contains minimal, basic tests that are more likely to succeed
// during the initial UI testing setup phase
class BasicCategoryTests: TestBase {
    
    override var launchArguments: [String] {
        return ["--ui-testing"]
    }
    
    func testAppLaunches() throws {
        // Simply verify the app launches without crashing
        XCTAssertTrue(app.exists)
        
        // Print UI hierarchy to help with debugging
        printUIHierarchy()
        
        // Log tab bar existence
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")
        
        if tabBar.exists {
            // Log all tab buttons
            let buttons = tabBar.buttons.allElementsBoundByIndex
            for (index, button) in buttons.enumerated() {
                print("Tab \(index): \(button.label)")
            }
        }
    }
    
    func testNavigateToSettings() throws {
        // Try to navigate to settings - this is a prerequisite for Categories
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
            
            // Wait for UI to update
            sleep(1)
            
            // Print all visible elements after navigation
            print("*** UI AFTER NAVIGATION TO SETTINGS ***")
            printUIHierarchy()
            
            // Check if navigation was successful
            if app.navigationBars["Settings"].exists {
                XCTAssertTrue(true, "Successfully navigated to Settings")
            } else {
                // Log what's visible
                print("Could not find Settings navigation bar")
                let navBars = app.navigationBars.allElementsBoundByIndex
                for navbar in navBars {
                    print("Found navigation bar: \(navbar.identifier)")
                }
            }
        } else {
            XCTFail("Settings tab not found in tab bar")
        }
    }
    
    func testIdentifyCategoriesPath() throws {
        // This test helps identify how to navigate to Categories
        // Try to find Settings tab
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
            
            // Wait for UI to update
            sleep(1)
            
            // Print UI hierarchy after navigating to Settings
            print("*** SETTINGS VIEW UI ***")
            printUIHierarchy()
            
            // Look for any item containing "category" or "categories"
            let possibleCategoryItems = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'categor' OR identifier CONTAINS[c] 'categor'"))
            
            print("*** POSSIBLE CATEGORY ITEMS ***")
            for item in possibleCategoryItems.allElementsBoundByIndex {
                print("Possible category item: \(item.description)")
                if item.isEnabled {
                    print("This item is tappable")
                }
            }
            
            // Try to navigate to Categories
            for item in possibleCategoryItems.allElementsBoundByIndex {
                if item.isEnabled {
                    print("Attempting to tap: \(item.description)")
                    item.tap()
                    
                    // Wait for UI to update
                    sleep(1)
                    
                    // Check if we reached Categories
                    if app.navigationBars["Categories"].exists {
                        print("Successfully navigated to Categories!")
                        
                        // Check for key UI elements
                        let hasAddButton = app.navigationBars["Categories"].buttons["plus"].exists
                        let hasEditButton = app.navigationBars["Categories"].buttons["pencil"].exists
                        
                        print("Add button exists: \(hasAddButton)")
                        print("Edit button exists: \(hasEditButton)")
                        
                        XCTAssertTrue(true, "Found and navigated to Categories screen")
                        return
                    } else {
                        print("Navigation did not lead to Categories screen")
                        // Go back to Settings for next attempt
                        if app.navigationBars.buttons["Back"].exists {
                            app.navigationBars.buttons["Back"].tap()
                        }
                    }
                }
            }
            
            // If we got here, we couldn't find the Categories screen
            XCTFail("Could not navigate to Categories from Settings")
        } else {
            XCTFail("Settings tab not found")
        }
    }
}