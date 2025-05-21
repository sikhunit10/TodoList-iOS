//
//  StringExtensions.swift
//  TodoListMore
//
//  Created by Codex on 2023.
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

    /// Return an `AttributedString` with URLs converted to tappable links.
    func linkified() -> AttributedString {
        var attributed = AttributedString(self)
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return attributed }

        let nsRange = NSRange(startIndex..., in: self)
        for match in detector.matches(in: self, options: [], range: nsRange) {
            guard let url = match.url,
                  let range = Range(match.range, in: self) else { continue }
            attributed[range].link = url
            attributed[range].foregroundColor = .blue
        }
        return attributed
    }
}
