# Todo List App for iOS

A modern Todo List application for iOS that works on both iPhone and iPad. The app stores data locally and syncs with iCloud based on user permissions.

## Features

- Create, view, edit, and delete tasks
- Organize tasks with color-coded categories
- Set due dates and priority levels
- Mark tasks as completed
- Filter tasks by status (all, today, upcoming, completed)
- Search tasks by title and description
- Local storage with CoreData
- iCloud sync with CloudKit
- Consistent iOS-native interface

## Project Structure

```
TodoListMore/
├── Models/
│   ├── Models.swift              # Core Data model templates
│   ├── TaskModels.swift          # Task-related enums and structs
│   └── TodoListMore.xcdatamodeld # CoreData model
├── Views/
│   ├── Tasks/
│   │   ├── TaskListView.swift    # Main task list
│   │   ├── TaskDetailView.swift  # Task details
│   │   └── TaskFormView.swift    # Add/edit task form
│   ├── Categories/
│   │   └── CategoryListView.swift # Category management
│   └── Settings/
│       └── SettingsView.swift     # App settings
├── Services/
│   ├── DataController.swift      # CoreData controller
│   └── CloudKitService.swift     # iCloud sync service
└── Utils/
    └── ColorExtensions.swift     # Color utilities
```

## Technical Details

### Architecture
- SwiftUI for interface design
- MVVM architecture pattern
- CoreData for local persistence
- CloudKit for iCloud synchronization
- Support for iPhone and iPad

### Requirements
- iOS 16.0+
- iPadOS 16.0+
- Xcode 14.0+
- Swift 5.7+
- Apple Developer Account (for CloudKit)

## Setup Instructions

1. Open the project in Xcode
2. Set up the CloudKit container:
   - Open the project settings
   - Go to the "Signing & Capabilities" tab
   - Add the "iCloud" capability
   - Check "CloudKit" and add a container identifier

3. Configure the CoreData model:
   - Open TodoListMore.xcdatamodeld
   - Create Task and Category entities with appropriate attributes and relationships
   - Generate NSManagedObject subclasses

4. Build and run the app

## Privacy

The app respects user privacy by:
- Only syncing data when the user explicitly grants permission
- Storing all data locally by default
- Providing clear options to enable/disable sync functionality

## License

This project is licensed under the MIT License - see the LICENSE file for details.