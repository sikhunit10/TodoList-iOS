//
//  SimpleTodoWidgetLiveActivity.swift
//  SimpleTodoWidget
//
//  Created by Harjot Singh on 05/04/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SimpleTodoWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SimpleTodoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SimpleTodoWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension SimpleTodoWidgetAttributes {
    fileprivate static var preview: SimpleTodoWidgetAttributes {
        SimpleTodoWidgetAttributes(name: "World")
    }
}

extension SimpleTodoWidgetAttributes.ContentState {
    fileprivate static var smiley: SimpleTodoWidgetAttributes.ContentState {
        SimpleTodoWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SimpleTodoWidgetAttributes.ContentState {
         SimpleTodoWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SimpleTodoWidgetAttributes.preview) {
   SimpleTodoWidgetLiveActivity()
} contentStates: {
    SimpleTodoWidgetAttributes.ContentState.smiley
    SimpleTodoWidgetAttributes.ContentState.starEyes
}
