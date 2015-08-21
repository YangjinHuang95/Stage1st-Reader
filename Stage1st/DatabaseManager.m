#import "DatabaseManager.h"
#import "CloudKitManager.h"
#import "S1AppDelegate.h"
#import "YapDatabaseFilteredView.h"
#import "MyDatabaseObject.h"
#import "S1Topic.h"

#import <Reachability/Reachability.h>

NSString *const UIDatabaseConnectionWillUpdateNotification = @"UIDatabaseConnectionWillUpdateNotification";
NSString *const UIDatabaseConnectionDidUpdateNotification  = @"UIDatabaseConnectionDidUpdateNotification";
NSString *const kNotificationsKey = @"notifications";

NSString *const Collection_Topics    = @"topics";
NSString *const Collection_CloudKit = @"cloudKit";

NSString *const Ext_View_Archive = @"archive";
NSString *const Ext_FilteredView_Archive = @"filteredArchive";
NSString *const Ext_CloudKit   = @"cloudKit";

NSString *const CloudKitZoneName = @"zone1";

DatabaseManager *MyDatabaseManager;


@implementation DatabaseManager

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		MyDatabaseManager = [[DatabaseManager alloc] init];
	});
}

+ (instancetype)sharedInstance
{
	return MyDatabaseManager;
}

+ (NSString *)databasePath
{
	NSString *databaseName = @"Stage1stYap.sqlite";
	
	NSURL *baseURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
	                                                        inDomain:NSUserDomainMask
	                                               appropriateForURL:nil
	                                                          create:YES
	                                                           error:NULL];
	
	NSURL *databaseURL = [baseURL URLByAppendingPathComponent:databaseName isDirectory:NO];
	
	return databaseURL.filePathURL.path;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Instance
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize database = database;
@synthesize cloudKitExtension = cloudKitExtension;

@synthesize uiDatabaseConnection = uiDatabaseConnection;
@synthesize bgDatabaseConnection = bgDatabaseConnection;

- (id)init
{
	NSAssert(MyDatabaseManager == nil, @"Must use sharedInstance singleton (global MyDatabaseManager)");
	
	if ((self = [super init]))
	{
		[self setupDatabase];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (YapDatabaseSerializer)databaseSerializer
{
	// This is actually the default serializer.
	// We just included it here for completeness.
	
	YapDatabaseSerializer serializer = ^(NSString *collection, NSString *key, id object){
		
		return [NSKeyedArchiver archivedDataWithRootObject:object];
	};
	
	return serializer;
}

- (YapDatabaseDeserializer)databaseDeserializer
{
	// Pretty much the default serializer,
	// but it also ensures that objects coming out of the database are immutable.
	
	YapDatabaseDeserializer deserializer = ^(NSString *collection, NSString *key, NSData *data){
		
		id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		if ([object isKindOfClass:[MyDatabaseObject class]])
		{
			[(MyDatabaseObject *)object makeImmutable];
		}
		
		return object;
	};
	
	return deserializer;
}

- (YapDatabasePreSanitizer)databasePreSanitizer
{
	YapDatabasePreSanitizer preSanitizer = ^(NSString *collection, NSString *key, id object){
		
		if ([object isKindOfClass:[MyDatabaseObject class]])
		{
			[object makeImmutable];
		}
		
		return object;
	};
	
	return preSanitizer;
}

- (YapDatabasePostSanitizer)databasePostSanitizer
{
	YapDatabasePostSanitizer postSanitizer = ^(NSString *collection, NSString *key, id object){
		
		if ([object isKindOfClass:[MyDatabaseObject class]])
		{
			[object clearChangedProperties];
		}
	};
	
	return postSanitizer;
}

- (void)setupDatabase
{
	NSString *databasePath = [[self class] databasePath];
	NSLog(@"databasePath: %@", databasePath);
	
	// Configure custom class mappings for NSCoding.
	// In a previous version of the app, the "S1Topic" class was named "S1TopicItem".
	// We renamed the class in a recent version.
	
	// [NSKeyedUnarchiver setClass:[S1Topic class] forClassName:@"S1TopicItem"];
	
	// Create the database
	
	database = [[YapDatabase alloc] initWithPath:databasePath
	                                  serializer:[self databaseSerializer]
	                                deserializer:[self databaseDeserializer]
	                                preSanitizer:[self databasePreSanitizer]
	                               postSanitizer:[self databasePostSanitizer]
	                                     options:nil];
	
	// FOR ADVANCED USERS ONLY
	//
	// Do NOT copy this blindly into your app unless you know exactly what you're doing.
	// https://github.com/yapstudios/YapDatabase/wiki/Object-Policy
	//
	database.defaultObjectPolicy = YapDatabasePolicyShare;
	database.defaultMetadataPolicy = YapDatabasePolicyShare;
	//
	// ^^^ FOR ADVANCED USERS ONLY ^^^
	
	
	
	// Setup database connection(s)
	
	uiDatabaseConnection = [database newConnection];
	uiDatabaseConnection.objectCacheLimit = 10000;
	uiDatabaseConnection.metadataCacheEnabled = NO;
	
	#if YapDatabaseEnforcePermittedTransactions
	uiDatabaseConnection.permittedTransactions = YDB_SyncReadTransaction | YDB_MainThreadOnly;
	#endif
	
	bgDatabaseConnection = [database newConnection];
	bgDatabaseConnection.objectCacheLimit = 0;
	bgDatabaseConnection.metadataCacheEnabled = NO;
	
	// Start the longLivedReadTransaction on the UI connection.
	
	[uiDatabaseConnection enableExceptionsForImplicitlyEndingLongLivedReadTransaction];
	[uiDatabaseConnection beginLongLivedReadTransaction];
	
    // Setup the extensions
    
    [self setupArchiveViewExtension];
    [self setupFilteredArchiveViewExtension];
    if (SYSTEM_VERSION_LESS_THAN(@"8") || ![[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSync"]) {
        // iOS 7 do not support cloud kit sync
        ;
    } else {
        // iOS 8 and more
        [self setupCloudKitExtension];
    }
    
    
    
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(yapDatabaseModified:)
	                                             name:YapDatabaseModifiedNotification
	                                           object:database];
}

- (void)setupArchiveViewExtension
{
	//
	// What is a YapDatabaseView ?
	//
	// https://github.com/yapstudios/YapDatabase/wiki/Views
	//
	// > If you're familiar with Core Data, it's kinda like a NSFetchedResultsController.
	// > But you should really read that wiki article, or you're likely to be a bit confused.
	//
	//
	// This view keeps a persistent "list" of S1Topic items sorted by timestamp.
	// We use it to drive the tableView.
	//
	
	YapDatabaseViewGrouping *orderGrouping = [YapDatabaseViewGrouping withObjectBlock:^NSString *(YapDatabaseReadTransaction *transaction, NSString *collection, NSString *key, id object) {
		if ([object isKindOfClass:[S1Topic class]])
		{
            S1Topic *topic = object;
            
            if (topic.lastViewedDate) {
                return [[S1Formatter sharedInstance] headerForDate:topic.lastViewedDate];
            } else {
                return @"Unknown Date";
            }
            // include in view
		}
		
		return nil; // exclude from view
	}];
	
    YapDatabaseViewSorting *orderSorting = [YapDatabaseViewSorting withObjectBlock:^NSComparisonResult(YapDatabaseReadTransaction *transaction, NSString *group, NSString *collection1, NSString *key1, id object1, NSString *collection2, NSString *key2, id object2) {
		// We want:
		// - Most recently created Todo at index 0.
		// - Least recent created Todo at the end.
		//
		// This is descending order (opposite of "standard" in Cocoa) so we swap the normal comparison.
        S1Topic *topic1 = object1;
        S1Topic *topic2 = object2;
		NSComparisonResult cmp = [topic1.lastViewedDate compare:topic2.lastViewedDate];
		
		if (cmp == NSOrderedAscending) return NSOrderedDescending;
		if (cmp == NSOrderedDescending) return NSOrderedAscending;
		
		return NSOrderedSame;
	}];
	
	YapDatabaseView *orderView =
	  [[YapDatabaseView alloc] initWithGrouping:orderGrouping
	                                    sorting:orderSorting
	                                 versionTag:NSLocalizedString(@"SystemLanguage", @"Just Identifier")];
	
    [database asyncRegisterExtension:orderView withName:Ext_View_Archive connection:self.bgDatabaseConnection completionQueue:NULL completionBlock:^(BOOL ready) {
        if (!ready) {
            NSLog(@"Error registering %@ !!!", Ext_View_Archive);
        }
    }];
}

- (void)setupFilteredArchiveViewExtension {
    YapDatabaseViewFiltering *filteringBlock = [YapDatabaseViewFiltering withObjectBlock:^BOOL(YapDatabaseReadTransaction *transaction, NSString *group, NSString *collection, NSString *key, id object) {
        return YES;
    }];
    
    YapDatabaseFilteredView *filteredView = [[YapDatabaseFilteredView alloc] initWithParentViewName:Ext_View_Archive filtering:filteringBlock versionTag:[NSString stringWithFormat:@"%@:%@:%@", NSLocalizedString(@"SystemLanguage", @"Just Identifier"), @"History", @""]];
    [database asyncRegisterExtension:filteredView withName:Ext_FilteredView_Archive connection:self.bgDatabaseConnection completionQueue:NULL completionBlock:^(BOOL ready) {
        if (!ready) {
            NSLog(@"Error registering %@ !!!", Ext_FilteredView_Archive);
        }
    }];
}

- (void)setupCloudKitExtension
{
	YapDatabaseCloudKitRecordHandler *recordHandler = [YapDatabaseCloudKitRecordHandler withObjectBlock:
	    ^(CKRecord *__autoreleasing *inOutRecordPtr, YDBCKRecordInfo *recordInfo,
		  NSString *collection, NSString *key, S1Topic *topic)
	{
		CKRecord *record = inOutRecordPtr ? *inOutRecordPtr : nil;
		if (record                          && // not a newly inserted object
		    !topic.hasChangedCloudProperties && // no sync'd properties changed in the todo
		    !recordInfo.keysToRestore        ) // and we don't need to restore "truth" values
		{
			// Thus we don't have any changes we need to push to the cloud
			return;
		}
		
		// The CKRecord will be nil when we first insert an object into the database.
		// Or if we've never included this item for syncing before.
		//
		// Otherwise we'll be handed a bare CKRecord, with only the proper CKRecordID
		// and the sync metadata set.
		
		BOOL isNewRecord = NO;
		
		if (record == nil)
		{
			CKRecordZoneID *zoneID =
			  [[CKRecordZoneID alloc] initWithZoneName:CloudKitZoneName ownerName:CKOwnerDefaultName];
			
			CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName:[topic.topicID stringValue] zoneID:zoneID];
			
			record = [[CKRecord alloc] initWithRecordType:@"topic" recordID:recordID];
			
			*inOutRecordPtr = record;
			isNewRecord = YES;
		}
		
		id <NSFastEnumeration> cloudKeys = nil;
		
		if (recordInfo.keysToRestore)
		{
			// We need to restore "truth" values for YapDatabaseCloudKit.
			// This happens when the extension is restarted,
			// and it needs to restore its change-set queue (to pick up where it left off).
			
			cloudKeys = recordInfo.keysToRestore;
		}
		else if (isNewRecord)
		{
			// This is a CKRecord for a newly inserted todo item.
			// So we want to get every single property,
			// including those that are read-only, and may have been set directly via the init method.
			
			cloudKeys = topic.allCloudProperties;
		}
		else
		{
			// We changed one or more properties of our Todo item.
			// So we need to copy only these changed values into the CKRecord.
			// That way YapDatabaseCloudKit can handle syncing it to the cloud.
			
			cloudKeys = topic.changedCloudProperties;
			
			// We can also instruct YapDatabaseCloudKit to store the originalValues for us.
			// This is optional, but comes in handy if we run into conflicts.
			recordInfo.originalValues = topic.originalCloudValues;
		}
		
		for (NSString *cloudKey in cloudKeys)
		{
			id cloudValue = [topic cloudValueForCloudKey:cloudKey];
			[record setObject:cloudValue forKey:cloudKey];
		}
	}];
	
	YapDatabaseCloudKitMergeBlock mergeBlock =
	^(YapDatabaseReadWriteTransaction *transaction, NSString *collection, NSString *key,
	  CKRecord *remoteRecord, YDBCKMergeInfo *mergeInfo)
	{
		if ([remoteRecord.recordType isEqualToString:@"topic"])
		{
			S1Topic *topic = [transaction objectForKey:key inCollection:collection];
			topic = [topic copy]; // make mutable copy
			
			// CloudKit doesn't tell us exactly what changed.
			// We're just being given the latest version of the CKRecord.
			// So it's up to us to figure out what changed.
			
			NSArray *allKeys = remoteRecord.allKeys;
			NSMutableArray *remoteChangedKeys = [NSMutableArray arrayWithCapacity:allKeys.count];
			
			for (NSString *key in allKeys)
			{
				id remoteValue = [remoteRecord objectForKey:key];
				id localValue = [topic cloudValueForCloudKey:key];
				
				if (![remoteValue isEqual:localValue])
				{
					id originalLocalValue = [mergeInfo.originalValues objectForKey:key];
					if (![remoteValue isEqual:originalLocalValue])
					{
						[remoteChangedKeys addObject:key];
					}
				}
			}
			
			NSMutableSet *localChangedKeys = [NSMutableSet setWithArray:mergeInfo.pendingLocalRecord.changedKeys];
			
			for (NSString *remoteChangedKey in remoteChangedKeys)
			{
				id remoteChangedValue = [remoteRecord valueForKey:remoteChangedKey];
				
				[topic setLocalValueFromCloudValue:remoteChangedValue forCloudKey:remoteChangedKey];
				[localChangedKeys removeObject:remoteChangedKey];
			}
			for (NSString *localChangedKey in localChangedKeys)
			{
				id localChangedValue = [mergeInfo.pendingLocalRecord valueForKey:localChangedKey];
				[mergeInfo.updatedPendingLocalRecord setObject:localChangedValue forKey:localChangedKey];
			}
			
			[transaction setObject:topic forKey:key inCollection:collection];
		}
	};
	
	YapDatabaseCloudKitOperationErrorBlock opErrorBlock =
	  ^(NSString *databaseIdentifier, NSError *operationError)
	{
		NSInteger ckErrorCode = operationError.code;
        NSLog(@"CKError: %@", operationError);
		if (ckErrorCode == CKErrorNetworkUnavailable ||
		    ckErrorCode == CKErrorNetworkFailure      )
		{
			[MyCloudKitManager handleNetworkError];
		}
		else if (ckErrorCode == CKErrorPartialFailure)
		{
			[MyCloudKitManager handlePartialFailure];
		}
		else if (ckErrorCode == CKErrorNotAuthenticated)
		{
			[MyCloudKitManager handleNotAuthenticated];
        }
        else if (ckErrorCode == CKErrorRequestRateLimited)
        {
            NSLog(@"Unhandled ckErrorCode: %ld", (long)ckErrorCode);
            NSLog(@"Unhandled ckError: %@", operationError);
        }
        else if (ckErrorCode == CKErrorUserDeletedZone)
        {
            NSLog(@"Unhandled ckErrorCode: %ld", (long)ckErrorCode);
            NSLog(@"Unhandled ckError: %@", operationError);
        }
		else
		{
			NSLog(@"Unhandled ckErrorCode: %ld", (long)ckErrorCode);
            NSLog(@"Unhandled ckError: %@", operationError);
		}
	};
	
	NSSet *topics = [NSSet setWithObject:Collection_Topics];
	YapWhitelistBlacklist *whitelist = [[YapWhitelistBlacklist alloc] initWithWhitelist:topics];
	
	YapDatabaseCloudKitOptions *options = [[YapDatabaseCloudKitOptions alloc] init];
	options.allowedCollections = whitelist;
	
	cloudKitExtension = [[YapDatabaseCloudKit alloc] initWithRecordHandler:recordHandler
	                                                            mergeBlock:mergeBlock
	                                                   operationErrorBlock:opErrorBlock
	                                                            versionTag:@"1"
	                                                           versionInfo:nil
	                                                               options:options];
	
	[cloudKitExtension suspend]; // Create zone(s)
	[cloudKitExtension suspend]; // Create zone subscription(s)
	[cloudKitExtension suspend]; // Initial fetchRecordChanges operation
	
	[database asyncRegisterExtension:cloudKitExtension withName:Ext_CloudKit completionBlock:^(BOOL ready) {
		if (!ready) {
			NSLog(@"Error registering %@ !!!", Ext_CloudKit);
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)yapDatabaseModified:(NSNotification *)ignored
{
	// Notify observers we're about to update the database connection
	
	[[NSNotificationCenter defaultCenter] postNotificationName:UIDatabaseConnectionWillUpdateNotification
	                                                    object:self];
	
	// Move uiDatabaseConnection to the latest commit.
	// Do so atomically, and fetch all the notifications for each commit we jump.
	
	NSArray *notifications = [uiDatabaseConnection beginLongLivedReadTransaction];
	
	// Notify observers that the uiDatabaseConnection was updated
	
	NSDictionary *userInfo = @{
	  kNotificationsKey : notifications,
	};

	[[NSNotificationCenter defaultCenter] postNotificationName:UIDatabaseConnectionDidUpdateNotification
	                                                    object:self
	                                                  userInfo:userInfo];
}

@end