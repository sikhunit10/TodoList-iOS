//
//  TodoWidgetsBundle.swift
//  SimpleTodoWidget
//
//  Created by Harjot Singh on 05/04/25.
//

import WidgetKit
import SwiftUI

@main
struct TodoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        PriorityTasksWidget()
        QuickAddTaskWidget()
    }
}