//
//  LinSpellObjC.h
//  LinSpell
//
//  Created by Shyngys Kassymov on 23.01.2018.
//  Copyright © 2018 Shyngys Kassymov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SuggestItemObjC : NSObject
@property (nonatomic, copy) NSString *term;
@property (nonatomic) int distance;
@property (nonatomic) int64_t count;
@end

@interface LinSpellObjC : NSObject

@property (nonatomic) int editDistanceMax;
@property (nonatomic) int verbose;

@property (nonatomic) int topResultsLimit;
@property (nonatomic) int maxlength;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *dictionaryLinear;

- (BOOL)loadDictionary:(NSString *)corpus termIndex:(int)termIndex countIndex:(int)countIndex;
- (BOOL)createDictionary:(NSString *)corpus;
- (NSArray<SuggestItemObjC *> *)lookupLinear:(NSString *)input editDistanceMax:(int)editDistanceMax;

@end
