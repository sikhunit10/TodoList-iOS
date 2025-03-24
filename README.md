# Todo List App for iOS

A modern Todo List application for iOS that works on both iPhone and iPad. The app stores data locally using CoreData.

## Features

- Create, view, edit, and delete tasks
- Organize tasks with color-coded categories
- Set due dates and priority levels
- Mark tasks as completed
- Filter tasks by status (all, today, upcoming, completed)
- Search tasks by title and description
- Local storage with CoreData
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
│   └── DataController.swift      # CoreData controller
└── Utils/
    └── ColorExtensions.swift     # Color utilities
```

## Technical Details

### Architecture
- SwiftUI for interface design
- MVVM architecture pattern
- CoreData for local persistence
- Support for iPhone and iPad

### Requirements
- iOS 16.0+
- iPadOS 16.0+
- Xcode 14.0+
- Swift 5.7+

## Setup Instructions

1. Open the project in Xcode

2. Configure the CoreData model:
   - Open TodoListMore.xcdatamodeld
   - Create Task and Category entities with appropriate attributes and relationships
   - Generate NSManagedObject subclasses

3. Build and run the app

## Privacy

The app respects user privacy by:
- Storing all data locally on the device
- No data is transmitted to external servers

## License

This project is licensed under the MIT License - see the LICENSE file for details.