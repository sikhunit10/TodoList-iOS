import Foundation
import SwiftUI

// Class to handle deep links from widgets
class DeepLinkHandler {
    
    // Deep link destinations
    enum DeepLinkDestination {
        case today
        case priority
        case newTask
        case none
    }
    
    // Parse URL to determine which destination to navigate to
    static func parseDeepLink(url: URL) -> DeepLinkDestination {
        guard url.scheme == "todolistmore" else {
            return .none
        }
        
        switch url.host {
        case "today":
            return .today
        case "priority":
            return .priority
        case "new":
            return .newTask
        default:
            return .none
        }
    }
}

// View modifier to handle deep link navigation
struct DeepLinkHandlerModifier: ViewModifier {
    @Binding var selection: Int
    @Binding var showNewTaskSheet: Bool
    
    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                let destination = DeepLinkHandler.parseDeepLink(url: url)
                handleNavigation(to: destination)
            }
    }
    
    private func handleNavigation(to destination: DeepLinkHandler.DeepLinkDestination) {
        switch destination {
        case .today:
            // Navigate to today's tasks (assuming tab index 0)
            selection = 0
        case .priority:
            // Navigate to tasks filtered by priority
            selection = 0 // Navigate to tasks tab first
            // Here you would also need to set a filter state for priority
        case .newTask:
            // Show the new task sheet
            showNewTaskSheet = true
        case .none:
            break
        }
    }
}

// Extension to make it easier to apply the modifier
extension View {
    func handleDeepLink(selection: Binding<Int>, showNewTaskSheet: Binding<Bool>) -> some View {
        self.modifier(DeepLinkHandlerModifier(selection: selection, showNewTaskSheet: showNewTaskSheet))
    }
}