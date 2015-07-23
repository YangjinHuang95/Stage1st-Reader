//
//  S1Tracer.h
//  Stage1st
//
//  Created by Suen Gabriel on 3/3/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

@import Foundation;
#import "S1DataCenter.h"

@class FMDatabase;
@class S1Topic;

@interface S1Tracer : NSObject<S1Backend>

@property (nonatomic, strong) FMDatabase *db;
@property (nonatomic, strong) FMDatabase *backgroundDb;

- (id)init;

- (BOOL)syncWithDatabasePath:(NSString *)databasePath;

+ (void)upgradeDatabase;

@end
