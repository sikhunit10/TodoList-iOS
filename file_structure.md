# TodoListApp File Structure

```
TodoListApp/
├── TodoListApp/
│   ├── App/
│   │   └── TodoListAppApp.swift         # App entry point
│   ├── Models/
│   │   ├── TodoListApp.xcdatamodeld     # CoreData model
│   │   ├── Task+CoreDataClass.swift     # Task entity
│   │   ├── Task+CoreDataProperties.swift
│   │   ├── Category+CoreDataClass.swift # Category entity
│   │   └── Category+CoreDataProperties.swift
│   ├── Views/
│   │   ├── TaskListView.swift           # Main task list
│   │   ├── TaskDetailView.swift         # Task details
│   │   ├── TaskFormView.swift           # Add/edit task form
│   │   ├── CategoryListView.swift       # Categories management
│   │   ├── SettingsView.swift           # App settings
│   │   └── Components/                  # Reusable UI components
│   ├── ViewModels/
│   │   ├── TaskViewModel.swift          # Task business logic
│   │   ├── CategoryViewModel.swift      # Category business logic
│   │   └── SettingsViewModel.swift      # Settings logic
│   ├── Services/
│   │   ├── DataController.swift         # CoreData controller
│   │   ├── CloudKitService.swift        # iCloud sync service
│   │   └── NotificationService.swift    # Local notifications
│   ├── Utils/
│   │   ├── Extensions/                  # Swift extensions
│   │   └── Helpers/                     # Utility functions
│   ├── Resources/
│   │   ├── Assets.xcassets              # Images and colors
│   │   └── Localizable.strings          # Text localization
│   └── Info.plist                       # App configuration
├── TodoListAppTests/                    # Unit tests
└── TodoListAppUITests/                  # UI tests
```