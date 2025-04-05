# TodoList Widgets Implementation

This folder contains the implementation of three Home Screen widgets for the TodoList app:

1. **Today's Tasks Widget**: Shows tasks due today
2. **Priority Tasks Widget**: Shows high priority tasks
3. **Quick Add Task Widget**: A button to quickly add new tasks

## Setting Up Widget Extension in Xcode

To integrate these widgets into your project, follow these steps:

1. Open your project in Xcode
2. Go to File > New > Target
3. Choose "Widget Extension" from the template selector
4. Name it "TodoWidgets"
5. Make sure "Include Configuration Intent" is NOT selected
6. Set deployment target to iOS 14.0 or higher
7. Click Finish

### Resolving @main Attribute Conflict

To resolve the "@main attribute can only apply to one type in a module" error:

1. Select your Widget Extension target
2. Go to Build Settings
3. Add a custom compiler flag in "Other Swift Flags": `-DEXTENSION`
4. This activates the conditional @main attribute in the TodoWidgets.swift file

## Post-Setup Configuration

1. Replace the auto-generated files with the files in this folder
2. Configure App Groups for data sharing:

   a. For the main app:
      - Select your app target
      - Go to "Signing & Capabilities"
      - Add capability "App Groups"
      - Create a new group: "group.com.yourcompany.TodoListMore" (update with your bundle ID)
      - Ensure the TodoListMore.entitlements file is included in your project

   b. For the widget extension:
      - Select your widget extension target
      - Go to "Signing & Capabilities"
      - Add capability "App Groups" 
      - Select the same group you created for the main app
3. Update the app's Info.plist to add URL scheme support:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.TodoListMore</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>todolistmore</string>
        </array>
    </dict>
</array>
```

4. Add handle for URL scheme in your `SceneDelegate.swift` or `App.swift`:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    
    if url.scheme == "todolistmore" {
        handleDeepLink(url: url)
    }
}

func handleDeepLink(url: URL) {
    switch url.host {
    case "today":
        // Navigate to today's tasks
        break
    case "priority":
        // Navigate to priority tasks
        break
    case "new":
        // Open new task form
        break
    default:
        break
    }
}
```

## Widget Features

### Today's Tasks Widget
- Shows a list of tasks due today
- Displays task title and due time
- Updates hourly and at midnight
- Supports small and medium sizes

### Priority Tasks Widget
- Shows high priority tasks
- Displays task title and due date
- Updates hourly
- Supports small and medium sizes

### Quick Add Task Widget
- Simple widget with a plus button
- Opens the app directly to the task creation screen
- Supports small size only

## Data Sharing

Widgets share data with the main app using a shared app group container for Core Data. The `TodoWidgetProvider` handles loading the persistent store and fetching relevant tasks.