//
//  DamerauLevenshtein.swift
//  LinSpell
//
//  Created by Shyngys Kassymov on 19.01.2018.
//  Copyright © 2018 Shyngys Kassymov. All rights reserved.
//

import Foundation

public final class EditDistance {

    /// Computes and returns the Damerau-Levenshtein edit distance between two strings,
    /// i.e. the number of insertion, deletion, sustitution, and transposition edits
    /// required to transform one string to the other. This value will be >= 0, where 0
    /// indicates identical strings. Comparisons are case sensitive, so for example,
    /// "Fred" and "fred" will have a distance of 1. This algorithm is basically the
    /// Levenshtein algorithm with a modification that considers transposition of two
    /// adjacent characters as a single edit.
    /// [Optimizing the Damerau-Levenshtein Algorithm in C#](http://blog.softwx.net/2015/01/optimizing-damerau-levenshtein_15.html)
    /// [SoftWx.Match](https://github.com/softwx/SoftWx.Match)
    ///
    /// - remark:
    /// See [Damerau–Levenshtein distance](http://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance)
    /// This is inspired by Sten Hjelmqvist' "Fast, memory efficient" algorithm, described
    /// at [Fast, memory efficient Levenshtein algorithm](http://www.codeproject.com/Articles/13525/Fast-memory-efficient-Levenshtein-algorithm).
    /// This version differs by adding additiona optimizations, and extending it to the Damerau-
    /// Levenshtein algorithm.
    /// Note that this is the simpler and faster optimal string alignment (aka restricted edit) distance
    /// that difers slightly from the classic Damerau-Levenshtein algorithm by imposing the restriction
    /// that no substring is edited more than once. So for example, "CA" to "ABC" has an edit distance
    /// of 2 by a complete application of Damerau-Levenshtein, but a distance of 3 by this method that
    /// uses the optimal string alignment algorithm. See wikipedia article for more detail on this
    ///
    /// - Parameters:
    ///   - string1: String being compared for distance.
    ///   - string2: String being compared against other string.
    ///   - maxDistance: The maximum edit distance of interest.
    /// - Returns: Int edit distance, >= 0 representing the number of edits required
    /// to transform one string to the other, or -1 if the distance is greater than the specified maxDistance.
    public static func damerauLevenshteinDistance(string1: String?, string2: String?, maxDistance: Int) -> Int {
        var string1 = string1 ?? ""
        var string2 = string2 ?? ""
        var maxDistance = maxDistance

        if string1.isEmpty {
            return string2.count
        } else if string2.isEmpty {
            return string1.count
        }

        // if strings of different lengths, ensure shorter string is in string1. This can result in a little
        // faster speed by spending more time spinning just the inner loop during the main processing.
        if string1.count > string2.count {
            let temp = string1; string1 = string2; string2 = temp; // swap string1 and string2
        }
        var sLen = string1.count // this is also the minimun length of the two strings
        var tLen = string2.count

        let string1Chars = Array(string1)
        let string2Chars = Array(string2)

        // suffix common to both strings can be ignored
        while sLen > 0 && string1Chars[sLen - 1] == string2Chars[tLen - 1] { sLen -= 1; tLen -= 1; }

        var start = 0
        if string1Chars[0] == string2Chars[0] || sLen == 0 { // if there'string1 a shared prefix, or all string1 matches string2'string1 suffix
            // prefix common to both strings can be ignored
            while start < sLen && string1Chars[start] == string2Chars[start] { start += 1 }
            sLen -= start // length of the part excluding common prefix and suffix
            tLen -= start

            // if all of shorter string matches prefix and/or suffix of longer string, then
            // edit distance is just the delete of additional characters present in longer string
            if (sLen == 0) {
                return tLen
            }

            let startIndex = string2.index(string2.startIndex, offsetBy: start)
            let endIndex = string2.index(startIndex, offsetBy: tLen)
            string2 = String(string2[startIndex..<endIndex])
        }
        let lenDiff = tLen - sLen
        if maxDistance < 0 || maxDistance > tLen {
            maxDistance = tLen
        } else if (lenDiff > maxDistance) {
            return -1
        }

        var v0 = [Int](repeating: 0, count: tLen)
        var v2 = [Int](repeating: 0, count: tLen) // stores one level further back (offset by +1 position)
        var j = 0
        while j < maxDistance {
            v0[j] = j + 1
            j += 1
        }
        while j < tLen {
            v0[j] = maxDistance + 1
            j += 1
        }

        let jStartOffset = maxDistance - (tLen - sLen)
        let haveMax = maxDistance < tLen
        var jStart = 0
        var jEnd = maxDistance
        var sChar = string1Chars[0]
        var current = 0
        for i in 0..<sLen {
            let prevsChar = sChar
            sChar = string1Chars[start + i]
            var tChar = string2Chars[0]
            var left = i
            current = left + 1
            var nextTransCost = 0
            // no need to look beyond window of lower right diagonal - maxDistance cells (lower right diag is i - lenDiff)
            // and the upper left diagonal + maxDistance cells (upper left is i)
            jStart += i > jStartOffset ? 1 : 0
            jEnd += jEnd < tLen ? 1 : 0
            for j in jStart..<jEnd {
                let above = current
                var thisTransCost = nextTransCost
                nextTransCost = v2[j]
                v2[j] = left // cost of diagonal (substitution)
                current = left // cost of diagonal (substitution)
                left = v0[j]    // left now equals current cost (which will be diagonal at next iteration)
                let prevtChar = tChar
                tChar = string2Chars[j]
                if sChar != tChar {
                    if (left < current) { current = left }   // insertion
                    if (above < current) { current = above } // deletion
                    current += 1
                    if i != 0 && j != 0
                        && sChar == prevtChar
                        && prevsChar == tChar {
                        thisTransCost += 1
                        if thisTransCost < current { current = thisTransCost } // transposition
                    }
                }
                v0[j] = current
            }
            if haveMax && v0[i + lenDiff] > maxDistance {
                return -1
            }
        }
        return current <= maxDistance ? current : -1
    }

}
