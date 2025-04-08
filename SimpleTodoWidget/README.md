# TodoList Widget Implementation

This widget extension provides three home screen widgets for the TodoList app:

1. **Today's Tasks Widget**: Shows tasks due today
   - Available in small and medium sizes
   - Deep links to the tasks list when tapped

2. **Priority Tasks Widget**: Shows high priority tasks
   - Available in small and medium sizes
   - Deep links to the tasks list when tapped

3. **Quick Add Task Widget**: Button to quickly add a new task
   - Available in small size only
   - Deep links to the new task form when tapped

## How to Use

1. Run the widget extension from Xcode:
   - Select the "SimpleTodoWidget" scheme
   - Run on a device or simulator
   - Use environment variables to specify the widget kind:
     - `__WidgetKind` = "TodayTasksWidget", "PriorityTasksWidget", or "QuickAddTaskWidget"

2. Add the widgets to your home screen:
   - Long press on the home screen
   - Tap the "+" button in the top-left corner
   - Scroll to find the TodoList widgets
   - Add your preferred widget to the home screen

3. Interact with the widgets:
   - View your tasks directly on the home screen
   - Tap a widget to open the app in the corresponding section

## Technical Details

- The widgets use App Groups to share data between the main app and the widget extension
- The group identifier `group.com.yourcompany.TodoListMore` must match in both entitlements files
- The widgets fetch data using CoreData from the shared container
- Deep linking is implemented with the URL scheme `todolistmore://`

## Troubleshooting

If the widget doesn't display any data:
1. Make sure the app group ID is correct in both entitlements files
2. Check that the CoreData model is compatible
3. Verify that the URL scheme is registered in the main app's Info.plist
4. Try restarting the device if changes don't appear immediately

## Environment Variables for Debugging

To debug specific widgets, set these environment variables in your scheme:
- `__WidgetKind`: The kind of widget to display (required)
- `_XCWidgetFamily`: The size of widget to display ("small" or "medium")