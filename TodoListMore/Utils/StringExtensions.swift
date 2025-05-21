//
//  TaskDetailView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import Foundation
import SwiftUI

extension String {
    /// Detect the first URL contained in the string
    func firstURL() -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(startIndex..., in: self)
        return detector.matches(in: self, options: [], range: range)
            .compactMap { $0.url }
            .first
    }

    /// Return an AttributedString where detected URLs become tappable links.
    /// Text outside the URLs remains unstyled.
    func linkified() -> AttributedString {
        let attributed = NSMutableAttributedString(string: self)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return AttributedString(attributed)
        }

        let nsRange = NSRange(location: 0, length: attributed.length)
        detector.enumerateMatches(in: self, options: [], range: nsRange) { match, _, _ in
            guard let match = match, let url = match.url else { return }
            attributed.addAttribute(.link, value: url, range: match.range)
            attributed.addAttribute(.foregroundColor, value: UIColor.blue, range: match.range)
        }

        return AttributedString(attributed)
    }
}
