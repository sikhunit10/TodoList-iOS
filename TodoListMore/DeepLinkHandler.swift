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

class DeepLinkManager: ObservableObject {
    @Published var currentDeepLink: DeepLink?
    
    func handle(url: URL) {
        if let deepLink = DeepLink(url: url) {
            self.currentDeepLink = deepLink
        }
    }
}