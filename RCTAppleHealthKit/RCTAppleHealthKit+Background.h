//
//  RCTAppleHealthKit+Background.h
//  RCTAppleHealthKit
//
//  Private header — imported only by implementation files within this library.
//  Not included in the public podspec headers.
//

#import "RCTAppleHealthKit.h"
#import <HealthKit/HealthKit.h>

@interface RCTAppleHealthKit (BackgroundPrivate)

- (NSNumber *)_beginHeadlessTaskWithCompletionHandler:(HKObserverQueryCompletionHandler)handler;
- (void)_releaseHeadlessTask:(NSNumber *)taskId;
- (void)_setPersistenceForTask:(NSNumber *)taskId
                     anchorKey:(NSString *)anchorKey
                   anchorValue:(NSString *)anchorValue
                  lastFetchKey:(NSString *)lastFetchKey;

+ (void)_persistAnchorKey:(NSString *)anchorKey
                    value:(NSString *)anchorValue
             lastFetchKey:(NSString *)lastFetchKey;

@end
