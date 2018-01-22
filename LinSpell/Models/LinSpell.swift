//
//  LinSpell.swift
//  LinSpell
//
//  Created by Shyngys Kassymov on 19.01.2018.
//  Copyright © 2018 Shyngys Kassymov. All rights reserved.
//

import Foundation

/// LinSpell: Spelling correction & Approximate string search
///
/// The LinSpell spelling correction algorithm does not require edit candidate generation or specialized data structures like BK-tree or Norvig's algorithm.
/// In most cases LinSpell ist faster and requires less memory compared to BK-tree or Norvig's algorithm.
/// LinSpell is language and character set independent.
public final class LinSpell {

    public enum VerboseType: Int {
        /// Top 0-3 suggestions
        case top

        /// All suggestions of smallest edit distance
        case allOfSmallestEdistDistance

        /// All suggestions <= editDistanceMax (slower, no early termination)
        case all
    }

    public static var editDistanceMax = 2
    public static var verbose = VerboseType.top
    public static var topResultsLimit = 3

    /// Maximum dictionary term length
    public static var maxlength = 0

    public static var dictionaryLinear = [String: Int64]()

    private static let regexPattern = "\\p{L}[\\p{L}']*(?:-\\p{L}+)*" // word in any language (includes `-` if needed, ex: tick-tick)
    private static var regex: NSRegularExpression?

    public struct SuggestItem: Hashable {
        public var term = ""
        public var distance = 0
        public var count = Int64(0)

        public var hashValue: Int {
            return term.hashValue
        }

        public static func ==(lhs: LinSpell.SuggestItem, rhs: LinSpell.SuggestItem) -> Bool {
            return lhs.term == rhs.term
        }
    }

    /// Сreate a non-unique wordlist from sample text
    /// language independent (e.g. works with Chinese characters)
    ///
    /// - Parameters:
    ///   - text: String to parse words
    /// - Returns: String array of parsed words
    private static func parseWords(text: String) -> [String] {
        do {
            if regex == nil {
                regex = try NSRegularExpression(pattern: regexPattern)
            }
            let results = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
            return results.map {
                String(text[Range($0.range, in: text)!])
            }
        } catch let error {
            print("Invalid regex: \(error.localizedDescription)")
            return []
        }
    }

    /// Load a frequency dictionary
    ///
    /// - Parameters:
    ///   - corpus: String path to dictionary file
    ///   - termIndex: Int index of column for words
    ///   - countIndex: Int index of column for words count
    /// - Returns: Bool indicating success or failure
    @discardableResult
    public static func loadDictionary(corpus: String, termIndex: Int, countIndex: Int) -> Bool {
        if !FileManager.default.fileExists(atPath: corpus) {
            return false
        }

        if let url = URL(string: corpus), let sr = StreamReader(url: url) {
            while let line = sr.nextLine() {
                let lineParts = line.components(separatedBy: .whitespaces)
                if lineParts.count >= 2 {
                    let key = lineParts[termIndex]
                    if let count = Int64(lineParts[countIndex]) {
                        dictionaryLinear[key] = min(Int64.max, count)
                    }
                }
            }
        }

        return true;
    }

    /// Create a frequency dictionary from a corpus
    ///
    /// - Parameters:
    ///   - corpus: String path to dictionary file
    /// - Returns: Bool indicating success or failure
    @discardableResult
    public static func createDictionary(corpus: String) -> Bool {
        if !FileManager.default.fileExists(atPath: corpus) {
            return false
        }

        if let url = URL(string: corpus), let sr = StreamReader(url: url) {
            while let line = sr.nextLine() {
                for key in parseWords(text: line) {
                    dictionaryLinear[key] = (dictionaryLinear[key] ?? 0) + 1
                }
            }
        }

        return true;
    }

    /// Linear search will be O(n), but with a few tweaks it will be almost always faster than a BK-tree. Please mind the constants!
    ///
    /// - Parameters:
    ///   - input: String input value
    ///   - editDistanceMax: Int to set maximum edit distance
    /// - Returns: Array of suggestions
    public static func lookupLinear(input: String, editDistanceMax: Int = editDistanceMax) -> ArraySlice<SuggestItem> {
        var suggestions = ArraySlice<SuggestItem>()

        var editDistanceMax2 = editDistanceMax

        // probably most lookups will be matches, lets get them straight O(1) from a hash table
        if verbose != .all, let value = dictionaryLinear[input] {
            var si = SuggestItem()
            si.term = input
            si.count = value
            si.distance = 0
            suggestions.append(si)

            return suggestions
        }

        for (key, value) in dictionaryLinear {
            // skip if strings length difference is bigger than editDistanceMax2
            if abs(key.endIndex.encodedOffset - input.endIndex.encodedOffset) > editDistanceMax2 {
                continue
            }

            // if already ed1 suggestion, there can be no better suggestion with smaller count: no need to calculate damlev
            if verbose == .top && suggestions.count > 0 && suggestions[0].distance == 1 && value <= suggestions[0].count {
                continue
            }

            let distance = EditDistance.damerauLevenshteinDistance(string1: input, string2: key, maxDistance: editDistanceMax2)

            // Calculate if only the Levenshtein distance is smaller than or equal to editDistanceMax
            if distance >= 0 && distance <= editDistanceMax {
                // v0: clear if better ed or better ed + count;
                // v1: clear if better ed
                // v2: all

                // do not process higher distances than those already found, if verbose < 2
                if verbose != .all && suggestions.count > 0 && distance > suggestions[0].distance {
                    continue
                }

                // we will calculate DamLev distance only to the smallest found distance so far
                if verbose != .all {
                    editDistanceMax2 = distance
                }

                // remove all existing suggestions of higher distance, if verbose < 2
                if verbose != .all && suggestions.count > 0 && suggestions[0].distance > distance {
                    suggestions.removeAll()
                }

                var si = SuggestItem()
                si.term = key
                si.count = value
                si.distance = distance
                suggestions.append(si)
            }
        }

        // sort by ascending edit distance, then by descending word frequency
        if verbose != .all {
            suggestions.sort(by: { (x, y) in
                if x.distance != y.distance {
                    return x.distance < y.distance
                }
                return x.count > y.count
            })
        }

        if verbose == .top && suggestions.count > 1 {
            let length = min(topResultsLimit, suggestions.count)
            return suggestions.prefix(upTo: length)
        }

        return suggestions
    }

}
