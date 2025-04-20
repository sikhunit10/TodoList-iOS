# UI Tests for TodoList-iOS

This directory contains UI tests for the TodoList-iOS app, focusing on testing the Categories screen.

## Adding Tests to Xcode

Follow these steps to add the UI tests to your Xcode project:

1. **Open your project in Xcode**

2. **Add a UI Test Target:**
   - Go to File > New > Target
   - Select "UI Testing Bundle" under the iOS section
   - Name it "TodoListMoreUITests"
   - Make sure "TodoListMore" is selected as the target to test
   - Click "Finish"

3. **Add existing test files:**
   - In Xcode's Project Navigator, right-click on the "TodoListMoreUITests" group
   - Select "Add Files to 'TodoListMoreUITests'..."
   - Navigate to and select all the test files in this directory
   - Make sure "Copy items if needed" is checked if the files aren't already in your project directory
   - Ensure "Add to targets" has "TodoListMoreUITests" selected
   - Click "Add"

4. **Create the folder structure:**
   - Right-click on the TodoListMoreUITests group in Xcode
   - Create groups for "CategoryTests" and "Helpers"
   - Drag the appropriate files into each group

5. **Configure test plan:**
   - In Xcode, go to Product > Scheme > Edit Scheme
   - Select "Test" in the left sidebar
   - Click the "+" button under Test Plans
   - Select "TodoListMore.xctestplan"

## Handling App Navigation

For the tests to reach the Categories screen, one of these approaches needs to be implemented:

### Option 1: Add direct navigation support to your app

In your app's SceneDelegate.swift or App.swift, add code to check for the test argument:

```swift
// In SceneDelegate's scene(_:willConnectTo:options:) or App's init()
if CommandLine.arguments.contains("--direct-to-categories") {
    // Set initial view controller to categories screen
    // OR set AppStorage/UserDefaults value to trigger navigation
}
```

### Option 2: Update the UI tests to match your app's navigation path

If you prefer not to modify your app, update the `navigateToCategories()` method in `CategoryUITests.swift` to match your app's actual navigation flow to the Categories screen.

## Running the Tests

1. Select the "TodoListMoreUITests" scheme in Xcode
2. Choose Product > Test (or press ⌘U)
3. To run an individual test, open the Test navigator (⌘6) and click the run button next to the specific test

## Exploring the Tests

The UI tests cover:
- Creating categories
- Editing categories
- Deleting categories (three different ways)
- Search functionality
- Empty state
- Edit mode UI

## Debugging UI Tests

If tests fail, use the `UIElementDebugTest` to identify UI elements and debug navigation issues.
This test prints detailed information about UI elements to help you determine the correct identifiers.