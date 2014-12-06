//
//  S1Topic.h
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface S1Topic : NSObject <NSCoding>
//Basic
@property (nonatomic, copy) NSNumber *topicID;
//To show in list
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSNumber *replyCount;

@property (nonatomic, copy) NSNumber *lastReplyCount;
//To satisfy content demand
@property (nonatomic, copy) NSNumber *authorUserID;


//For Search
@property (nonatomic, copy) NSNumber *fID;
@property (nonatomic, copy) NSString *authorUserName;

@property (nonatomic, copy) NSNumber *totalPageCount;
@property (nonatomic, copy) NSDate *lastReplyDate;

@property (nonatomic, copy) NSMutableDictionary *floors;

//For Reply
@property (nonatomic, copy) NSString *formhash;

//For Tracing
@property (nonatomic, copy) NSNumber *lastViewedPage;
@property (nonatomic, copy) NSNumber *lastViewedPosition;
@property (nonatomic, copy) NSDate *lastViewedDate;
@property (nonatomic, copy) NSDate *favoriteDate;

@property (nonatomic, copy) NSNumber *visitCount;
@property (nonatomic, copy) NSNumber *favorite;

- (void)addDataFromTracedTopic:(S1Topic *)topic;
@end
