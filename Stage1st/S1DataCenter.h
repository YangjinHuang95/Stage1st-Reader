//
//  S1DataCenter.h
//  Stage1st
//
//  Created by Zheng Li on 10/3/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>
@class S1Tracer;
@class S1Topic;
@class S1Floor;
@interface S1DataCenter : NSObject

@property (strong, nonatomic) S1Tracer *tracer;

//For topic list View Controller
- (BOOL)hasCacheForKey:(NSString *)keyID;

- (void)topicsForKey:(NSString *)keyID shouldRefresh:(BOOL)refresh success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;

- (void)loadNextPageForKey:(NSString *)keyID success:(void (^)(NSArray *topicList))success failure:(void (^)(NSError *error))failure;

//For Content View Controller
- (void)floorsForTopic:(S1Topic *)topic withPage:(NSNumber *)page success:(void (^)(NSArray *floorList))success failure:(void (^)(NSError *error))failure;

- (void)replySpecificFloor:(S1Floor *)floor inTopic:(S1Topic *)topic atPage:(NSNumber *)page withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure;

- (void)replyTopic:(S1Topic *)topic withText:(NSString *)text success:(void (^)())success failure:(void (^)(NSError *error))failure;

//Database
- (NSMutableArray *)historyTopicsWithSearchWord:(NSString *)searchWord;
- (void)removeTopicFromHistory:(NSNumber *)topicID;

- (NSMutableArray *)favoriteTopicsWithSearchWord:(NSString *)searchWord;
- (void)setTopicFavoriteState:(NSNumber *)topicID withState:(BOOL)state;

- (S1Topic *)tracedTopic:(NSNumber *)key;

//About Network
- (void)cancelRequest;

- (void)clearTopicListCache;
@end
