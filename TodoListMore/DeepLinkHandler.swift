//
//  DeepLinkHandler.swift
//  TodoListMore
//
//  Created by Harjot Singh on 05/04/25.
//

import SwiftUI

enum DeepLink: Equatable {
    case today
    case priority
    case newTask
    
    /// String identifier for plist-safe notifications
    var rawValue: String {
        switch self {
        case .today: return "today"
        case .priority: return "priority"
        case .newTask: return "new"
        }
    }
    
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let scheme = components.scheme,
              scheme == "todolistmore" else {
            return nil
        }
        
        guard let host = components.host else {
            return nil
        }
        
        switch host {
        case "today":
            self = .today
        case "priority":
            self = .priority
        case "new":
            self = .newTask
        default:
            return nil
        }
    }
}
// MARK: - Notification Names
extension Notification.Name {
    /// Posted when a deep link is received from widget or URL
    static let deepLinkReceived = Notification.Name("deepLinkReceived")
}

class DeepLinkManager: ObservableObject {
    @Published var currentDeepLink: DeepLink?
    
    func handle(url: URL) {
        if let deepLink = DeepLink(url: url) {
            // Ensure we update on the main thread since this is an @Published property
            DispatchQueue.main.async {
                self.currentDeepLink = deepLink
                
                // Post a notification with plist-safe payload
                NotificationCenter.default.post(
                    name: .deepLinkReceived,
                    object: nil,
                    userInfo: ["deepLink": deepLink.rawValue]
                )
            }
        } else {
            print("Failed to parse deep link from URL: \(url)")
        }
    }
}