//
//  UIElementDebugTest.swift
//  TodoListMoreUITests
//
//  Created for TodoList-iOS.
//

import XCTest

class UIElementDebugTest: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }
    
    func testInspectUIHierarchy() throws {
        // This test will simply log the UI hierarchy to help with debugging
        
        // Wait for app to fully load
        sleep(2)
        
        // Log available tabs
        let tabBar = app.tabBars.firstMatch
        print("Tab bar exists: \(tabBar.exists)")
        if tabBar.exists {
            let tabButtons = tabBar.buttons.allElementsBoundByIndex
            print("Available tabs: \(tabButtons.map { "\($0.label) (id: \($0.identifier))" })")
        }
        
        // Try navigating to Settings if available
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
            print("Tapped Settings tab")
            
            // Wait for navigation
            sleep(1)
            
            // Log all elements in the settings view
            let allElements = app.descendants(matching: .any)
            print("*** ALL UI ELEMENTS IN CURRENT VIEW ***")
            for element in allElements.allElementsBoundByIndex {
                if element.identifier.isEmpty && element.label.isEmpty {
                    continue
                }
                
                print("Element: Type=\(element.elementType), Label='\(element.label)', ID='\(element.identifier)', Enabled=\(element.isEnabled)")
            }
            
            print("*** TABLE CELLS ***")
            let cells = app.tables.cells.allElementsBoundByIndex
            for (index, cell) in cells.enumerated() {
                print("Cell \(index): \(cell.label) (id: \(cell.identifier))")
                
                // Print child elements of the cell
                let cellElements = cell.descendants(matching: .any).allElementsBoundByIndex
                for childElement in cellElements {
                    if !childElement.label.isEmpty || !childElement.identifier.isEmpty {
                        print("  - Child: Type=\(childElement.elementType), Label='\(childElement.label)', ID='\(childElement.identifier)'")
                    }
                }
            }
            
            // Try finding categories related elements
            print("*** SEARCHING FOR CATEGORIES ELEMENTS ***")
            let categoriesQuery = allElements.matching(NSPredicate(format: "label CONTAINS[c] 'categor' OR identifier CONTAINS[c] 'categor'"))
            let categoriesElements = categoriesQuery.allElementsBoundByIndex
            
            for element in categoriesElements {
                print("Category Element: Type=\(element.elementType), Label='\(element.label)', ID='\(element.identifier)', Enabled=\(element.isEnabled)")
            }
            
            // If found, try tapping the first matching element
            if let categoryElement = categoriesElements.first, categoryElement.isEnabled {
                print("Attempting to tap: \(categoryElement.label)")
                categoryElement.tap()
                
                // Wait for navigation
                sleep(1)
                
                // Check if we reached the Categories screen
                let navBar = app.navigationBars["Categories"]
                print("Categories navigation bar exists: \(navBar.exists)")
                
                if navBar.exists {
                    print("Successfully navigated to Categories!")
                    
                    // Log navigation bar buttons
                    let navButtons = navBar.buttons.allElementsBoundByIndex
                    print("Navigation bar buttons: \(navButtons.map { "\($0.label) (id: \($0.identifier))" })")
                }
            }
        }
        
        // Add any other navigation paths you want to test
        // This is just to help identify the correct UI elements for testing
    }
}