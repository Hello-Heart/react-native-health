//
//  RCTAppleHealthKit.h
//  RCTAppleHealthKit
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTUtils.h>
#import <React/RCTLog.h>
#import <React/RCTEventDispatcher.h>

@interface RCTAppleHealthKit : RCTEventEmitter <RCTBridgeModule>

@property (nonatomic) HKHealthStore *healthStore;
@property (nonatomic, assign) BOOL hasListeners;
@property (atomic, assign) BOOL backgroundHandlerRegistered;

- (HKHealthStore *)_initializeHealthStore;
- (void)isHealthKitAvailable:(RCTResponseSenderBlock)callback;
- (void)initializeHealthKit:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback;
- (void)getModuleInfo:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback;
- (void)getAuthorizationStatus:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback;
- (void)initializeBackgroundObservers:(RCTBridge *)bridge;
- (void)initializeBackgroundObservers:(RCTBridge *)bridge metrics:(nullable NSArray<NSString *> *)metrics;
- (void)disableBackgroundSyncForMetrics:(nullable NSArray<NSString *> *)metrics
                              completion:(nullable dispatch_block_t)completion;
- (void)emitEventWithName:(NSString *)name andPayload:(NSDictionary *)payload;

// Thread-safe registry of currently-armed background observer queries, keyed by
// the human-readable observer type string (e.g. 'HeartRate', 'SleepAnalysis').
- (void)registerActiveObserverQuery:(HKObserverQuery *)query forType:(NSString *)type;
- (nullable HKObserverQuery *)removeActiveObserverQueryForType:(NSString *)type;
- (NSArray<NSString *> *)activeObserverTypes;

// Background Headless Task support
- (void)launchHeadlessTask:(NSNumber *)taskId withType:(NSString *)type results:(NSDictionary *)results;

@end
