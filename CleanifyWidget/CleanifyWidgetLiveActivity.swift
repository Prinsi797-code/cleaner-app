//
//  CleanifyWidgetLiveActivity.swift
//  CleanifyWidget
//
//  Created by Aniket Dhandhukiya on 17/07/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CleanifyWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        
        var emoji: String
    }

    
    var name: String
}

struct CleanifyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CleanifyWidgetAttributes.self) { context in
            
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                
                
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    
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

extension CleanifyWidgetAttributes {
    fileprivate static var preview: CleanifyWidgetAttributes {
        CleanifyWidgetAttributes(name: "World")
    }
}

extension CleanifyWidgetAttributes.ContentState {
    fileprivate static var smiley: CleanifyWidgetAttributes.ContentState {
        CleanifyWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CleanifyWidgetAttributes.ContentState {
         CleanifyWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CleanifyWidgetAttributes.preview) {
   CleanifyWidgetLiveActivity()
} contentStates: {
    CleanifyWidgetAttributes.ContentState.smiley
    CleanifyWidgetAttributes.ContentState.starEyes
}
