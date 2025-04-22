//
//  CategoryTestSuite.swift
//  TodoListMoreUITests
//
//  Created for TodoList-iOS.
//

import XCTest

class CategoryTestSuite: XCTestCase {
    
    // This test suite runs all category related UI tests
    
    // Define a type for the test case collection
    static var allTests: [(String, Any)] = [
        // Basic navigation and setup tests
        ("testAppLaunches", BasicCategoryTests.testAppLaunches as Any),
        ("testNavigateToSettings", BasicCategoryTests.testNavigateToSettings as Any),
        ("testIdentifyCategoriesPath", BasicCategoryTests.testIdentifyCategoriesPath as Any),

        // Display tests
        ("testCategoryListDisplays", CategoryUITests.testCategoryListDisplays as Any),
        ("testEmptyState", CategoryUITests.testEmptyState as Any),
        ("testLoadingState", CategoryUITests.testLoadingState as Any),

        // Create tests
        ("testCreateCategory", CategoryUITests.testCreateCategory as Any),
        ("testCreateCategoryWithAllColors", CategoryUITests.testCreateCategoryWithAllColors as Any),
        ("testCreateCategoryWithEmptyName", CategoryUITests.testCreateCategoryWithEmptyName as Any),

        // Edit tests
        ("testEditCategory", CategoryUITests.testEditCategory as Any),
        ("testEditModeUI", CategoryUITests.testEditModeUI as Any),

        // Delete tests
        ("testDeleteCategorySwipe", CategoryUITests.testDeleteCategorySwipe as Any),
        ("testDeleteCategoryEditMode", CategoryUITests.testDeleteCategoryEditMode as Any),
        ("testDeleteMultipleCategories", CategoryUITests.testDeleteMultipleCategories as Any),

        // Search tests
        ("testSearchCategory", CategoryUITests.testSearchCategory as Any)
    ]
}