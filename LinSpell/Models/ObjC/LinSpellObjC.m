//
//  LinSpellObjC.m
//  LinSpell
//
//  Created by Shyngys Kassymov on 23.01.2018.
//  Copyright © 2018 Shyngys Kassymov. All rights reserved.
//

#import "LinSpellObjC.h"
#import "DamerauLevenshtein.h"
#import "FileReader.h"

@implementation SuggestItemObjC

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[SuggestItemObjC class]]) {
        return [self.term isEqualToString:((SuggestItemObjC *) object).term];
    }
    return false;
}

- (NSUInteger)hash {
    return self.term.hash;
}

@end

@interface LinSpellObjC()
@property (nonatomic, copy) NSString *regexPattern;
@property (nonatomic, strong) NSRegularExpression *regex;
@end

@implementation LinSpellObjC

- (instancetype)init {
    self = [super init];

    if (self) {
        self.editDistanceMax = 2;
        self.verbose = 0;

        self.topResultsLimit = 3;

        self.dictionaryLinear = [NSMutableDictionary new];
    }

    return self;
}

#pragma mark - Methods

/**
 Сreate a non-unique wordlist from sample text
 language independent (e.g. works with Chinese characters)

 @param text NSString to parse words
 @return NSString array of parsed words
 */
- (NSArray<NSString *> *)parseWords:(NSString *)text {
    NSError *error;

    if (!self.regexPattern) {
        self.regexPattern = @"";
    }
    if (!self.regex) {
        self.regex = [[NSRegularExpression alloc] initWithPattern:self.regexPattern options:NSRegularExpressionCaseInsensitive error:&error];
    }

    if (!error) {
        NSArray<NSTextCheckingResult *> *results = [self.regex matchesInString:text options:NSMatchingAnchored range:NSMakeRange(0, text.length)];
        NSMutableArray *parsedWords = [NSMutableArray new];
        for (NSTextCheckingResult *result in results) {
            [parsedWords addObject:[text substringWithRange:result.range]];
        }
        return parsedWords;
    }

    NSLog(@"Invalid regex: %@", error.localizedDescription);
    return @[];
}

/**
 Load a frequency dictionary

 @param corpus NSString path to dictionary file
 @param termIndex int index of column for words
 @param countIndex int index of column for words count
 @return BOOL indicating success or failure
 */
- (BOOL)loadDictionary:(NSString *)corpus termIndex:(int)termIndex countIndex:(int)countIndex {
    if (![[NSFileManager defaultManager] fileExistsAtPath:corpus]) {
        return false;
    }

    FileReader *fileReader = [[FileReader alloc] initWithFilePath:corpus];
    [fileReader enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSArray<NSString *> *lineParts = [line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (lineParts.count >= 2) {
            NSString *key = lineParts[termIndex];
            NSString *countStr = lineParts[countIndex];
            NSNumber *countNum = @(countStr.longLongValue);
            self.dictionaryLinear[key] = countNum;
        }
    }];

    return true;
}

/**
 Create a frequency dictionary from a corpus

 @param corpus NSString path to dictionary file
 @return BOOL indicating success or failure
 */
- (BOOL)createDictionary:(NSString *)corpus {
    if (![[NSFileManager defaultManager] fileExistsAtPath:corpus]) {
        return false;
    }

    FileReader *fileReader = [[FileReader alloc] initWithFilePath:corpus];
    [fileReader enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        for (NSString *key in [self parseWords:line]) {
            NSNumber *count = self.dictionaryLinear[key];
            self.dictionaryLinear[key] = count ? @(count.longLongValue + 1) : @((long long) 1);
        }
    }];

    return true;
}

/**
 Linear search will be O(n), but with a few tweaks it will be almost always faster than a BK-tree. Please mind the constants!

 @param input NSString input value
 @param editDistanceMax int to set maximum edit distance
 @return NSArray of suggestions
 */
- (NSArray<SuggestItemObjC *> *)lookupLinear:(NSString *)input editDistanceMax:(int)editDistanceMax {
    NSMutableArray<SuggestItemObjC *> *suggestions = [NSMutableArray new];

    int editDistanceMax2 = editDistanceMax;

    // probably most lookups will be matches, lets get them straight O(1) from a hash table
    NSNumber *valueNum = self.dictionaryLinear[input];
    if (self.verbose < 2 && valueNum) {
        SuggestItemObjC *si = [SuggestItemObjC new];
        si.term = input;
        si.count = [valueNum longLongValue];
        si.distance = 0;
        [suggestions addObject:si];

        return suggestions;
    }

    for (NSString *key in self.dictionaryLinear.allKeys) {
        NSNumber *value = self.dictionaryLinear[key];

        // skip if strings length difference is bigger than editDistanceMax2
        if (abs((int) key.length - (int) input.length) > editDistanceMax2) continue;

        // if already ed1 suggestion, there can be no better suggestion with smaller count: no need to calculate damlev
        if ((self.verbose == 0) && (suggestions.count > 0) && (suggestions[0].distance == 1) && (value.longLongValue <= suggestions[0].count)) continue;

        int distance = [DamerauLevenshtein damerauLevenshteinDistance:input string2:key maxDistance:editDistanceMax2];

        // Calculate if only the Levenshtein distance is smaller than or equal to editDistanceMax
        if ((distance >= 0) && (distance <= editDistanceMax)) {
            // v0: clear if better ed or better ed+count;
            // v1: clear if better ed
            // v2: all

            // do not process higher distances than those already found, if verbose<2
            if ((self.verbose < 2) && (suggestions.count > 0) && (distance > suggestions[0].distance)) continue;

            // we will calculate DamLev distance only to the smallest found distance sof far
            if (self.verbose < 2) editDistanceMax2 = distance;

            // remove all existing suggestions of higher distance, if verbose<2
            if ((self.verbose < 2) && (suggestions.count > 0) && (suggestions[0].distance > distance)) [suggestions removeAllObjects];

            SuggestItemObjC *si = [SuggestItemObjC new];
            si.term = key;
            si.count = value.longLongValue;
            si.distance = distance;
            [suggestions addObject:si];
        }
    }

    // sort by ascending edit distance, then by descending word frequency
    NSSortDescriptor *sortByDistance = [NSSortDescriptor sortDescriptorWithKey:@"distance" ascending:true];
    NSSortDescriptor *sortByCount = [NSSortDescriptor sortDescriptorWithKey:@"count" ascending:false];
    [suggestions sortUsingDescriptors:@[sortByDistance, sortByCount]];

    if ((self.verbose == 0) && (suggestions.count > 1)) return [suggestions subarrayWithRange:NSMakeRange(0, MIN(self.topResultsLimit, suggestions.count))];

    return suggestions;
}

@end
