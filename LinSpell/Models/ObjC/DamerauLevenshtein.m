//
//  DamerauLevenshtein.m
//  LinSpell
//
//  Created by Shyngys Kassymov on 23.01.2018.
//  Copyright © 2018 Shyngys Kassymov. All rights reserved.
//

#import "DamerauLevenshtein.h"

@implementation DamerauLevenshtein

+ (int)damerauLevenshteinDistance:(NSString *)string1 string2:(NSString *)string2 maxDistance:(int)maxDistance {
    if (string1 == nil || string1.length == 0) {
        return string2 == nil ? (int) string2.length : 0;
    } else if (string2 == nil || string2.length == 0) {
        return (int) string1.length;
    }

    if (string1.length > string2.length) {
        NSString *temp = string1; string1 = string2; string2 = temp; // swap string1 and string2
    }
    int sLen = (int) string1.length; // this is also the minimun length of the two strings
    int tLen = (int) string2.length;

    const char *str1Chars = [string1 UTF8String];
    const char *str2Chars = [string2 UTF8String];

    // suffix common to both strings can be ignored
    while ((sLen > 0) && (str1Chars[sLen - 1] == str2Chars[tLen - 1])) { sLen--; tLen--; }

    int start = 0;
    if ((str1Chars[0] == str2Chars[0]) || (sLen == 0)) { // if there'string1 a shared prefix, or all string1 matches string2'string1 suffix
        // prefix common to both strings can be ignored
        while ((start < sLen) && (str1Chars[start] == str2Chars[start])) start++;
        sLen -= start; // length of the part excluding common prefix and suffix
        tLen -= start;

        // if all of shorter string matches prefix and/or suffix of longer string, then
        // edit distance is just the delete of additional characters present in longer string
        if (sLen == 0) return tLen;

        char subbuff[tLen + 1];
        memcpy(subbuff, &str2Chars[start], tLen);
        subbuff[tLen] = '\0';
        str2Chars = subbuff;
    }
    int lenDiff = tLen - sLen;
    if ((maxDistance < 0) || (maxDistance > tLen)) {
        maxDistance = tLen;
    } else if (lenDiff > maxDistance) return -1;

    int v0[tLen];
    int v2[tLen]; // stores one level further back (offset by +1 position)
    int j;
    for (j = 0; j < maxDistance; j++) v0[j] = j + 1;
    for (; j < tLen; j++) v0[j] = maxDistance + 1;

    int jStartOffset = maxDistance - (tLen - sLen);
    bool haveMax = maxDistance < tLen;
    int jStart = 0;
    int jEnd = maxDistance;
    char sChar = str1Chars[0];
    int current = 0;
    for (int i = 0; i < sLen; i++) {
        char prevsChar = sChar;
        sChar = str1Chars[start + i];
        char tChar = str2Chars[0];
        int left = i;
        current = left + 1;
        int nextTransCost = 0;
        // no need to look beyond window of lower right diagonal - maxDistance cells (lower right diag is i - lenDiff)
        // and the upper left diagonal + maxDistance cells (upper left is i)
        jStart += (i > jStartOffset) ? 1 : 0;
        jEnd += (jEnd < tLen) ? 1 : 0;
        for (j = jStart; j < jEnd; j++) {
            int above = current;
            int thisTransCost = nextTransCost;
            nextTransCost = v2[j];
            v2[j] = current = left; // cost of diagonal (substitution)
            left = v0[j];    // left now equals current cost (which will be diagonal at next iteration)
            char prevtChar = tChar;
            tChar = str2Chars[j];
            if (sChar != tChar) {
                if (left < current) current = left;   // insertion
                if (above < current) current = above; // deletion
                current++;
                if ((i != 0) && (j != 0)
                    && (sChar == prevtChar)
                    && (prevsChar == tChar)) {
                    thisTransCost++;
                    if (thisTransCost < current) current = thisTransCost; // transposition
                }
            }
            v0[j] = current;
        }
        if (haveMax && (v0[i + lenDiff] > maxDistance)) return -1;
    }
    return (current <= maxDistance) ? current : -1;
}

@end
