//
//  DamerauLevenshtein.h
//  LinSpell
//
//  Created by Shyngys Kassymov on 23.01.2018.
//  Copyright © 2018 Shyngys Kassymov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DamerauLevenshtein : NSObject

+ (int)damerauLevenshteinDistance:(NSString *)string1 string2:(NSString *)string2 maxDistance:(int)maxDistance;

@end
