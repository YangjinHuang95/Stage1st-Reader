//
//  S1Topic.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1Topic.h"

/**
 * Keys for encoding / decoding (to avoid typos)
 **/
static NSString *const k_version = @"version";
static NSString *const k_topicID = @"topicID";
static NSString *const k_title  = @"title";
static NSString *const k_replyCount = @"replyCount";
static NSString *const k_fID  = @"fID";
static NSString *const k_lastViewedDate = @"lastViewedPage";
static NSString *const k_lastViewedPage = @"lastModified";
static NSString *const k_lastViewedPosition = @"lastViewedPosition";
static NSString *const k_favorite = @"favorite";
static NSString *const k_favoriteDate = @"favoriteDate";

@implementation S1Topic : MyDatabaseObject

- (instancetype)initWithRecord:(CKRecord *)record
{
    if (![record.recordType isEqualToString:@"topic"])
    {
        NSAssert(NO, @"Attempting to create topic from non-topic record"); // For debug builds
        return nil;                                                      // For release builds
    }
    
    if ((self = [super init]))
    {
        _topicID = @([record.recordID.recordName integerValue]);
        
        NSSet *cloudKeys = self.allCloudProperties;
        for (NSString *cloudKey in cloudKeys)
        {
            if (![cloudKey isEqualToString:k_topicID])
            {
                [self setLocalValueFromCloudValue:[record objectForKey:cloudKey] forCloudKey:cloudKey];
            }
        }
    }
    return self;
}


#pragma mark - Coding

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super init])) {
        _topicID = [aDecoder decodeObjectForKey:k_topicID];
        _title = [aDecoder decodeObjectForKey:k_title];
        _fID = [aDecoder decodeObjectForKey:k_fID];
        _replyCount = [aDecoder decodeObjectForKey:k_replyCount];
        _lastViewedDate = [aDecoder decodeObjectForKey:k_lastViewedDate];
        _lastViewedPage = [aDecoder decodeObjectForKey:k_lastViewedPage];
        _lastViewedPosition = [aDecoder decodeObjectForKey:k_lastViewedPosition];
        _favorite = [aDecoder decodeObjectForKey:k_favorite];
        _favoriteDate = [aDecoder decodeObjectForKey:k_favoriteDate];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_topicID forKey:k_topicID];
    [aCoder encodeObject:_title forKey:k_title];
    [aCoder encodeObject:_fID forKey:k_fID];
    [aCoder encodeObject:_replyCount forKey:k_replyCount];
    [aCoder encodeObject:_lastViewedDate forKey:k_lastViewedDate];
    [aCoder encodeObject:_lastViewedPage forKey:k_lastViewedPage];
    [aCoder encodeObject:_lastViewedPosition forKey:k_lastViewedPosition];
    [aCoder encodeObject:_favorite forKey:k_favorite];
    [aCoder encodeObject:_favoriteDate forKey:k_favoriteDate];
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone
{
    S1Topic *copy = [super copyWithZone:zone]; // Be sure to invoke [MyDatabaseObject copyWithZone:] !
    copy->_topicID = _topicID;
    copy->_title = _title;
    copy->_replyCount = _replyCount;
    copy->_lastReplyCount = _lastReplyCount;
    copy->_favorite = _favorite;
    copy->_favoriteDate = _favoriteDate;
    copy->_lastViewedDate = _lastViewedDate;
    copy->_lastViewedPosition = _lastViewedPosition;
    copy->_highlight = _highlight;
    copy->_authorUserID = _authorUserID;
    copy->_authorUserName = _authorUserName;
    copy->_totalPageCount = _totalPageCount;
    copy->_fID = _fID;
    copy->_formhash = _formhash;
    copy->_lastViewedPage = _lastViewedPage;
    copy->_message = _message;
    //TODO: Make it clear if we should copy floors.
    return copy;
}
#pragma mark - Update

- (void)addDataFromTracedTopic:(S1Topic *)topic {
    if (self.topicID == nil && topic.topicID != nil) {
        self.topicID = topic.topicID;
    }
    if (self.title == nil && topic.title != nil) {
        self.title = topic.title;
    }
    if (self.replyCount == nil && topic.replyCount != nil) {
        self.replyCount = topic.replyCount;
    }
    if (self.fID == nil && topic.fID != nil) {
        self.fID = topic.fID;
    }
    self.lastReplyCount = topic.replyCount;
    self.lastViewedPage = topic.lastViewedPage;
    self.lastViewedPosition = topic.lastViewedPosition;
    self.favorite = topic.favorite;
}

- (void)updateFromTopic:(S1Topic *)topic {
    if (topic.title != nil) {
        self.title = topic.title;
    }
    if (topic.replyCount != nil) {
        self.replyCount = topic.replyCount;
    }
    if (topic.totalPageCount != nil) {
        self.totalPageCount = topic.totalPageCount;
    }
    if (topic.authorUserID != nil) {
        self.authorUserID = topic.authorUserID;
    }
    if (topic.authorUserName != nil) {
        self.authorUserName = topic.authorUserName;
    }
    if (topic.formhash != nil) {
        self.formhash = topic.formhash;
    }
    if (topic.message != nil) {
        self.message = topic.message;
    }
}

- (BOOL)absorbTopic:(S1Topic *)topic {
    if ([topic.topicID isEqualToNumber:self.topicID]) {
        if ([topic.lastViewedDate timeIntervalSince1970] > [self.lastViewedDate timeIntervalSince1970]) {
            self.title = topic.title;
            self.replyCount = topic.replyCount;
            self.fID = topic.fID;
            self.lastViewedDate = topic.lastViewedDate;
            self.lastViewedPage = topic.lastViewedPage;
            self.lastViewedPosition = topic.lastViewedPosition;
            return YES;
        }
    }
    return NO;
    
}
/*
+ (NSValueTransformer *)lastViewedDateEntityAttributeTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSNumber *seconds) {
        return [[NSDate alloc] initWithTimeIntervalSince1970: [seconds doubleValue]];
    } reverseBlock:^(NSDate *date) {
        return [NSNumber numberWithDouble:[date timeIntervalSince1970]];
    }];
}*/

#pragma mark MyDatabaseObject overrides

+ (BOOL)storesOriginalCloudValues
{
    return YES;
}

+ (NSMutableDictionary *)mappings_localKeyToCloudKey
{
    NSMutableDictionary *mappings_localKeyToCloudKey = [super mappings_localKeyToCloudKey];
    //mappings_localKeyToCloudKey[@"creationDate"] = @"created";
    [mappings_localKeyToCloudKey removeObjectForKey:@"highlight"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"formhash"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"totalPageCount"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"floors"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"message"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"lastReplyCount"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"authorUserID"];
    [mappings_localKeyToCloudKey removeObjectForKey:@"authorUserName"];
    return mappings_localKeyToCloudKey;
}

- (id)cloudValueForCloudKey:(NSString *)cloudKey
{
    // Override me if needed.
    // For example:
    //
    // - (id)cloudValueForCloudKey:(NSString *)cloudKey
    // {
    //     if ([cloudKey isEqualToString:@"color"])
    //     {
    //         // We store UIColor in the cloud as a string (r,g,b,a)
    //         return ConvertUIColorToNSString(self.color);
    //     }
    //     else
    //     {
    //         return [super cloudValueForCloudKey:cloudKey];
    //     }
    // }
    
    return [super cloudValueForCloudKey:cloudKey];
}

- (void)setLocalValueFromCloudValue:(id)cloudValue forCloudKey:(NSString *)cloudKey
{
    // Override me if needed.
    // For example:
    //
    // - (void)setLocalValueFromCloudValue:(id)cloudValue forCloudKey:(NSString *)cloudKey
    // {
    //     if ([cloudKey isEqualToString:@"color"])
    //     {
    //         // We store UIColor in the cloud as a string (r,g,b,a)
    //         self.color = ConvertNSStringToUIColor(cloudValue);
    //     }
    //     else
    //     {
    //         return [super setLocalValueForCloudValue:cloudValue cloudKey:cloudKey];
    //     }
    // }
    
    return [super setLocalValueFromCloudValue:cloudValue forCloudKey:cloudKey];
}

#pragma mark KVO overrides

- (void)setNilValueForKey:(NSString *)key
{
    if ([key isEqualToString:@"priority"]) {
        //self.priority = TodoPriorityNormal;
    }
    if ([key isEqualToString:@"isDone"]) {
        //self.isDone = NO;
    }
    else {
        [super setNilValueForKey:key];
    }
}


@end
