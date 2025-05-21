//
//  StringExtensions.swift
//  TodoListMore
//
//  Created by Codex on 2023.
//

import Foundation

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
}
