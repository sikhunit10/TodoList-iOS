//
//  SimpleTodoWidgetBundle.swift
//  SimpleTodoWidget
//
//  Created by Harjot Singh on 05/04/25.
//

import WidgetKit
import SwiftUI

@main
struct SimpleTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        SimpleTodoWidget()
        SimpleTodoWidgetControl()
        SimpleTodoWidgetLiveActivity()
    }
}
