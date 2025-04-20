//
//  TestBase.swift
//  TodoListMoreUITests
//
//  Created for TodoList-iOS.
//

import XCTest

// Base class for all UI tests to inherit from
class TestBase: XCTestCase {
    var app: XCUIApplication!
    
    // Override this method to set specific launch arguments for your test
    var launchArguments: [String] {
        return ["--ui-testing"]
    }
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launch()
        
        // Delay to ensure app has fully launched
        sleep(1)
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Helper Methods
    
    // Prints all visible UI elements to the console - useful for debugging
    func printUIHierarchy() {
        let elements = app.descendants(matching: .any).allElementsBoundByIndex
        
        print("*** UI HIERARCHY ***")
        for element in elements {
            if !element.label.isEmpty || !element.identifier.isEmpty {
                print("Element: Type=\(element.elementType), Label='\(element.label)', ID='\(element.identifier)', Enabled=\(element.isEnabled)")
            }
        }
        
        // Handle special elements
        print("*** Navigation Bars ***")
        for navbar in app.navigationBars.allElementsBoundByIndex {
            print("NavBar: \(navbar.identifier) - Exists: \(navbar.exists)")
        }
        
        print("*** Tab Bars ***")
        for tabbar in app.tabBars.allElementsBoundByIndex {
            print("TabBar: \(tabbar.identifier) - Exists: \(tabbar.exists)")
            for button in tabbar.buttons.allElementsBoundByIndex {
                print("  - Button: \(button.label)")
            }
        }
    }
    
    // Wait for an element to appear
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}