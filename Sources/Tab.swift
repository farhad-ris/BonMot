//
//  Tab.swift
//  BonMot
//
//  Created by Brian King on 9/28/16.
//  Copyright © 2016 Raizlabs. All rights reserved.
//

#if os(OSX)
    import AppKit
#else
    import UIKit
#endif

/// A Composable that creates a tab character with a calculated space from the beginning of the line.
public enum Tab {
    /// A spacer Tab will introduce a tab of the specified amount from the current position in the String
    case spacer(CGFloat)

    /// A headIndent Tab will introduce a tab of the specified amount from the current position in the String, and update the
    /// headIndent value in the containing NSParagraphStyle
    case headIndent(CGFloat)

}

extension Tab: Composable {

    public func append(to attributedString: NSMutableAttributedString, baseStyle: StringStyle) {
        let attributes = baseStyle.attributes
        #if os(iOS)
            // Embed the tab in the attributes
            let tabAttributes = EmbeddedTransformationHelpers.embed(transformation: self, to: attributes)
        #else
            let tabAttributes: StyleAttributes = attributes
        #endif
        let tabRange = NSRange(location: attributedString.length, length: 1)

        attributedString.append(NSAttributedString(string: Special.tab.description, attributes: tabAttributes))

        // Calculate the tab spacing
        update(string: attributedString, in: tabRange)
    }

}

extension Tab {

    /// Update the tab calculation for the tabs in `range`. This will create a NSTabStop in the paragraph style with the specified padding
    /// from the beginning of the line. This supports multiple tabs in one line, and multiple lines.
    ///
    /// This implementation conforms to `AttributedStringTransformation`, but since this is used when the adaptive code may not be included, the
    /// conformance is not declared here.
    ///
    /// - parameter string: The attributedString to update
    /// - parameter in: The range to perform the tab calculations on
    func update(string attributedString: NSMutableAttributedString, in range: NSRange) {
        let string = attributedString.string as NSString

        // Lookup the range this paragraph is operating on.
        // This is the range from `range` to the preceeding newline or the start of the string.
        let precedingRange = NSRange(location: 0, length: NSMaxRange(range))
        var leadingNewline = string.rangeOfCharacter(from: CharacterSet.newlines, options: [.backwards], range: precedingRange).location
        leadingNewline = (leadingNewline == NSNotFound) ? 0 : leadingNewline + 1
        let paragraphRange = NSRange(location: leadingNewline, length: NSMaxRange(range) - leadingNewline)

        // Search backwards by attribute cluster to obtain the paragraph inside of `paragraphRange`.
        var paragraphCursor = range.location
        var paragraphAttribute: Any?
        while paragraphCursor >= leadingNewline && paragraphAttribute == nil {
            var attributeRange = NSRange()
            let attributes = attributedString.attributes(at: paragraphCursor, effectiveRange: &attributeRange)
            paragraphAttribute = attributes[NSParagraphStyleAttributeName]
            paragraphCursor = attributeRange.location - 1
        }

        // Prepare the NSMutableParagraphStyle and configure it over the paragraphRange
        let paragraph: NSMutableParagraphStyle
        if paragraphAttribute == nil {
            paragraph = NSMutableParagraphStyle()
        }
        else if let existingParagraph = paragraphAttribute as? NSMutableParagraphStyle {
            paragraph = existingParagraph
        }
        else if let existingParagraph = paragraphAttribute as? NSParagraphStyle {
            paragraph = existingParagraph.mutableParagraphStyleCopy()
        }
        else {
            fatalError("Non paragraphStyle held in NSParagraphStyleAttributeName.")
        }

        // Enumerate tabs over the range of the paragraph, keeping count of the tabs.
        var enumerationRange = paragraphRange
        var tabIndex = 0
        while true {
            let tabRange = string.range(of: "\t", options: [], range: enumerationRange)
            guard tabRange.location != NSNotFound else { break }

            // If the tab is in `range`, recalculate the tab at tabIndex.
            if NSLocationInRange(tabRange.location, range) {

                // Calculate the length of the string before the tab. Since tabs are relative to the paragraph range,
                // start at the start of the effective range for NSParagraphStyleAttributeName
                let preTab = attributedString.attributedSubstring(from: NSRange(location: paragraphRange.location, length: tabRange.location - paragraphRange.location))
                let max = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
                let contentWidth = preTab.boundingRect(with: max, options: .usesLineFragmentOrigin, context: nil).width

                // Add the padding and update the NSTextTab at tabIndex.
                let tabStop = contentWidth + padding
                paragraph.tabStops[tabIndex] = NSTextTab(textAlignment: .natural, location: tabStop, options: [:])

                // Update the paragraph object if it is a headIndent tab.
                if case .headIndent = self {
                    paragraph.headIndent = tabStop
                }
            }
            // Update the enumerationRange and tabIndex for the next pass
            enumerationRange.length = NSMaxRange(enumerationRange) - NSMaxRange(tabRange)
            enumerationRange.location = NSMaxRange(tabRange)
            tabIndex += 1
        }
        attributedString.addAttribute(NSParagraphStyleAttributeName, value: paragraph, range: paragraphRange)
    }

    var padding: CGFloat {
        switch self {
        case let .spacer(padding): return padding
        case let .headIndent(padding): return padding
        }
    }

}