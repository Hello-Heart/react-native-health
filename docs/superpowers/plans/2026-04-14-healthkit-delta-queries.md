# HealthKit Delta Query Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add delta (anchored) query support so apps know exactly what changed in HealthKit — added and deleted records — without re-fetching all data. Supports reactive push (observer emits delta immediately) and proactive pull (app fetches delta on demand).

**Architecture:**
- **Reactive**: upgrade background observer — seed anchor at registration, run anchored query on every HealthKit change, emit `healthKit:<Type>:delta` with `{ added, deleted, anchor }`, persist anchor in `NSUserDefaults`.
- **Proactive**: new `getDeltaSamples` native method — caller passes anchor, gets delta back, manages anchor in AsyncStorage.
- Both modes use a new generic `fetchAnchoredSamplesOfType:` method. The existing `fetchAnchoredWorkouts` is the reference implementation (line ~502 in Queries.m).

**Tech Stack:** Objective-C, `HKAnchoredObjectQuery`, `NSUserDefaults`, React Native bridge, TypeScript

---

## Verification — what already exists in react-native-health

| What | Status | Location |
|---|---|---|
| `getAnchoredWorkouts` (workouts only) | ✅ exists | `index.js:39`, `RCTAppleHealthKit.m:245` |
| `fetchAnchoredWorkouts:` (workouts only) | ✅ exists | `Queries.m:502` |
| `fetchWorkoutRoute:` (route only) | ✅ exists | `Queries.m:70` |
| `hkAnchorFromOptions:` utility | ✅ exists | `Utils.m:262` |
| `anchor` field in `HealthInputOptions` | ✅ exists | `index.d.ts:566` |
| `AnchoredQueryResults` type | ✅ exists | `index.d.ts:894` |
| `getDeltaSamples` for any non-workout type | ❌ missing | — |
| `healthKit:<Type>:delta` event | ❌ missing | — |
| `NSUserDefaults` anchor persistence | ❌ missing | — |
| `defaultHKUnitForType:` helper | ❌ missing | — |
| `fetchAnchoredSamplesOfType:` generic method | ❌ missing | — |
| `Periods` / `HealthPeriod` constant | ❌ missing | — |
| Observer seeding + delta emission | ❌ missing | — |
| `deletedObjects` handled in `fetchAnchoredWorkouts` | ❌ declared but ignored at line 512 | `Queries.m:512` |

## Verification — what already exists in mobileapp-core

| What | Status | Location |
|---|---|---|
| `HealthPeriod` string union | ✅ done | `types.ts:28` |
| `resolveDateRange` (period → dates) | ✅ done | `timeRange.ts` — full test coverage |
| `HealthMetric` enum (17 metrics) | ✅ done | `types.ts:3` |
| `HealthQueryResult.deletedIds` + `anchor` | ✅ placeholder | `types.ts:83-84` — always `[]`/`undefined` |
| `HealthQueryOptions.anchor` | ✅ ready | `types.ts:108` — not wired to SDK |
| `METRIC_REGISTRY` (17 metrics → HK method/type/unit) | ✅ done | `metricRegistry.ts` |
| `HealthKitProvider.fetchSamples` | ✅ date-range only | `HealthKitProvider.ts:83` — anchor TODO at line 102 |
| `queryHealth`, `useHealthQuery` | ✅ done | `queryHealth.ts`, `useHealthQuery.ts` |
| Observer event listener for `:delta` | ❌ missing | — |
| `HealthKitProvider` anchor path | ❌ missing | `HealthKitProvider.ts:102` — explicit TODO |

---

## Dependency order — must be done in this sequence

```
[react-native-health]
  Task 1  defaultHKUnitForType: helper
    ↓
  Task 2  fetchAnchoredSamplesOfType: (generic anchored query)
    ↓
  Task 3  getDeltaSamples RCT_EXPORT_METHOD + healthKit:%@:delta event
    ↓
  Task 4  Observer upgrade: seed anchor + emit :delta on change
    ↓
  Task 5  Periods constant (src/constants/Periods.js)
    ↓
  Task 6  JS API (getDeltaSamples + getDeltaSamplesForPermissions in index.js)
    ↓
  Task 7  TypeScript types (HealthPeriod, DeletedSample, DeltaQueryResult, DeltaQueryOptions)
    ↓
  Task 8  API docs (docs/getDeltaSamples.md)

[mobileapp-core — blocked on Tasks 1–4 above]
  Task 9   HealthKitProvider anchor path (wire getDeltaSamples when anchor present)
    ↓
  Task 10  Observer listener (handle healthKit:<Type>:delta events)
```

---

## How the app uses this (complete reference)

### Reactive mode — observer pushes delta on HealthKit change

```js
// 1. Register once at app start (already exists, gets upgraded by Task 4)
AppleHealthKit.initializeBackgroundObservers()

// 2. Listen for delta events — fires immediately when HealthKit changes
const emitter = new NativeEventEmitter(NativeModules.AppleHealthKit)

emitter.addListener('healthKit:HeartRate:delta', ({ added, deleted, anchor }) => {
  // added:   HealthValue[] — new samples since last delivery
  // deleted: { id: string }[] — UUIDs removed since last delivery
  localStore.addSamples('HeartRate', added)
  localStore.removeSamples('HeartRate', deleted.map(d => d.id))
  // anchor is informational here — observer manages its own anchor in NSUserDefaults
})
```

**What the observer guarantees:**
- First delivery only contains data added/deleted **after** observer registration (anchor seeded at setup — no historical dump)
- Each delivery contains only what changed since the previous delivery
- Deletions carry UUID only — HealthKit discards original values on delete
- `healthKit:<Type>:new` still fires alongside `:delta` for backwards compatibility

---

### Proactive mode — app fetches delta on demand

App manages the anchor in AsyncStorage. Pass it in, get an updated one back.

```js
import AsyncStorage from '@react-native-async-storage/async-storage'

async function syncHeartRate() {
  const anchor = await AsyncStorage.getItem('hk_anchor_HeartRate') ?? undefined

  AppleHealthKit.getDeltaSamples(
    { type: 'HeartRate', unit: 'bpm', anchor },
    async (err, { added, deleted, anchor: newAnchor }) => {
      if (err) return
      await AsyncStorage.setItem('hk_anchor_HeartRate', newAnchor)
      localStore.addSamples(added)
      localStore.removeSamples(deleted.map(d => d.id))
    }
  )
}
```

---

### Proactive mode — fetch by date range or period

```js
import { Periods } from 'react-native-health'

// Last 3 months — resolves natively to startDate
AppleHealthKit.getDeltaSamples(
  { type: 'HeartRate', unit: 'bpm', period: Periods.last3Months },
  (err, { added, deleted, anchor }) => { ... }
)

// Explicit date range
AppleHealthKit.getDeltaSamples(
  { type: 'HeartRate', unit: 'bpm', startDate: '2026-01-01T00:00:00.000Z' },
  (err, { added, deleted, anchor }) => { ... }
)
```

---

### Proactive mode — parallel multi-type fetch

```js
AppleHealthKit.getDeltaSamplesForPermissions(
  [
    { type: 'HeartRate',          unit: 'bpm',   anchor: anchors.HeartRate },
    { type: 'StepCount',          unit: 'count', anchor: anchors.StepCount },
    { type: 'ActiveEnergyBurned',                anchor: anchors.ActiveEnergyBurned },
  ],
  (err, results) => {
    // results.HeartRate          → { added, deleted, anchor }
    // results.StepCount          → { added, deleted, anchor }
    // results.ActiveEnergyBurned → { added, deleted, anchor }
  }
)
```

---

### Fetch mode summary

| Options | Behaviour |
|---|---|
| `anchor` | Delta since last sync — only what changed |
| `startDate` / `endDate` | All samples in explicit window |
| `period: Periods.last3Months` | All samples in last N days/months |
| `anchor` + `period` | Delta since anchor, bounded to period window |
| none | All HealthKit history for this type (avoid in production) |

---

### Result shape

```ts
{
  anchor:  string            // Store this — pass on next call
  added:   HealthValue[]     // New/updated samples
  deleted: { id: string }[]  // UUIDs of deleted samples — original data gone
}
```

---

## Files changed

| File | Change | Task |
|---|---|---|
| `RCTAppleHealthKit/RCTAppleHealthKit+Utils.h` | Declare `defaultHKUnitForType:` | 1 |
| `RCTAppleHealthKit/RCTAppleHealthKit+Utils.m` | Implement `defaultHKUnitForType:` | 1 |
| `RCTAppleHealthKit/RCTAppleHealthKit+Queries.h` | Declare `fetchAnchoredSamplesOfType:` | 2 |
| `RCTAppleHealthKit/RCTAppleHealthKit+Queries.m` | Implement `fetchAnchoredSamplesOfType:`; upgrade `setObserverForType:` | 2, 4 |
| `RCTAppleHealthKit/RCTAppleHealthKit.m` | Add `getDeltaSamples` export; add `delta` to `supportedEvents` | 3 |
| `src/constants/Periods.js` | New — `Periods` constant | 5 |
| `src/constants/index.js` | Export `Periods` | 5 |
| `index.js` | Add `getDeltaSamples`, `getDeltaSamplesForPermissions`, export `Periods` | 6 |
| `index.d.ts` | Add `HealthPeriod`, `DeletedSample`, `DeltaQueryResult`, `DeltaQueryOptions`; method signatures | 7 |
| `docs/getDeltaSamples.md` | API documentation | 8 |
| `mobileapp-core/src/health/providers/HealthKitProvider.ts` | Anchor path for `fetchSamples` | 9 |
| `mobileapp-core/src/health/providers/HealthKitProvider.ts` | Observer listener setup | 10 |

---

# TASK 1 — `defaultHKUnitForType:` helper

Needed by the observer (no unit from caller) and as fallback in `getDeltaSamples`.

**Files:**
- Modify: `RCTAppleHealthKit/RCTAppleHealthKit+Utils.h`
- Modify: `RCTAppleHealthKit/RCTAppleHealthKit+Utils.m`

- [ ] **Step 1.1 — Add declaration to Utils.h**

Add after `+ (HKUnit *)hkUnitFromOptions:(NSDictionary *)options key:(NSString *)key withDefault:(HKUnit *)defaultValue;`:

```objc
+ (HKUnit *)defaultHKUnitForType:(NSString *)type;
```

- [ ] **Step 1.2 — Implement in Utils.m**

Add after `hkAnchorFromOptions:` (around line 271):

```objc
+ (HKUnit *)defaultHKUnitForType:(NSString *)type {
    if ([@[@"HeartRate", @"RestingHeartRate", @"WalkingHeartRateAverage"] containsObject:type]) {
        return [HKUnit unitFromString:@"count/min"];
    }
    if ([@[@"HeartRateVariabilitySDNN"] containsObject:type]) {
        return [HKUnit secondUnitWithMetricPrefix:HKMetricPrefixMilli];
    }
    if ([@[@"ActiveEnergyBurned", @"BasalEnergyBurned"] containsObject:type]) {
        return [HKUnit kilocalorieUnit];
    }
    if ([@[@"Running", @"Walking", @"Cycling", @"Swimming"] containsObject:type]) {
        return [HKUnit meterUnit];
    }
    if ([@[@"Vo2Max"] containsObject:type]) {
        return [HKUnit unitFromString:@"ml/(kg*min)"];
    }
    return [HKUnit countUnit];
}
```

- [ ] **Step 1.3 — Commit**
```bash
git add RCTAppleHealthKit/RCTAppleHealthKit+Utils.h RCTAppleHealthKit/RCTAppleHealthKit+Utils.m
git commit -m "feat: add defaultHKUnitForType utility for anchored queries"
```

---

# TASK 2 — Generic `fetchAnchoredSamplesOfType:`

The core method. Template is existing `fetchAnchoredWorkouts:` at Queries.m:502.
Key fix over `fetchAnchoredWorkouts`: properly handles `deletedObjects` (currently declared but ignored at line 512).

**Files:**
- Modify: `RCTAppleHealthKit/RCTAppleHealthKit+Queries.h`
- Modify: `RCTAppleHealthKit/RCTAppleHealthKit+Queries.m`

- [ ] **Step 2.1 — Add declaration to Queries.h**

Add alongside existing method declarations:

```objc
- (void)fetchAnchoredSamplesOfType:(HKQuantityType *)quantityType
                              unit:(HKUnit *)unit
                         predicate:(NSPredicate *)predicate
                            anchor:(HKQueryAnchor *)anchor
                             limit:(NSUInteger)lim
                        completion:(void (^)(NSDictionary *, NSError *))completion;
```

- [ ] **Step 2.2 — Implement in Queries.m after `fetchAnchoredWorkouts:` (after line ~591)**

```objc
- (void)fetchAnchoredSamplesOfType:(HKQuantityType *)quantityType
                              unit:(HKUnit *)unit
                         predicate:(NSPredicate *)predicate
                            anchor:(HKQueryAnchor *)anchor
                             limit:(NSUInteger)lim
                        completion:(void (^)(NSDictionary *, NSError *))completion {

    void (^handlerBlock)(HKAnchoredObjectQuery *query,
                         NSArray<__kindof HKSample *> *sampleObjects,
                         NSArray<HKDeletedObject *> *deletedObjects,
                         HKQueryAnchor *newAnchor,
                         NSError *error);

    handlerBlock = ^(HKAnchoredObjectQuery *query,
                     NSArray<__kindof HKSample *> *sampleObjects,
                     NSArray<HKDeletedObject *> *deletedObjects,
                     HKQueryAnchor *newAnchor,
                     NSError *error) {

        if (error) {
            if (completion) { completion(nil, error); }
            return;
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableArray *added   = [NSMutableArray arrayWithCapacity:sampleObjects.count];
            NSMutableArray *deleted = [NSMutableArray arrayWithCapacity:deletedObjects.count];

            for (HKQuantitySample *sample in sampleObjects) {
                @try {
                    double value        = [sample.quantity doubleValueForUnit:unit];
                    NSString *startDate = [RCTAppleHealthKit buildISO8601StringFromDate:sample.startDate];
                    NSString *endDate   = [RCTAppleHealthKit buildISO8601StringFromDate:sample.endDate];
                    NSString *device    = @"";
                    if (@available(iOS 11.0, *)) {
                        device = [[sample sourceRevision] productType] ?: @"";
                    } else {
                        device = [[sample device] name] ?: @"iPhone";
                    }
                    [added addObject:@{
                        @"id":         [[sample UUID] UUIDString],
                        @"value":      @(value),
                        @"unit":       [unit unitString],
                        @"startDate":  startDate,
                        @"endDate":    endDate,
                        @"sourceName": [[[sample sourceRevision] source] name] ?: @"",
                        @"sourceId":   [[[sample sourceRevision] source] bundleIdentifier] ?: @"",
                        @"device":     device,
                        @"metadata":   sample.metadata ?: @{},
                    }];
                } @catch (NSException *e) {
                    NSLog(@"RNHealth: fetchAnchoredSamplesOfType serialization error: %@", e);
                }
            }

            for (HKDeletedObject *obj in deletedObjects) {
                [deleted addObject:@{ @"id": [[obj UUID] UUIDString] }];
            }

            NSData   *anchorData   = [NSKeyedArchiver archivedDataWithRootObject:newAnchor];
            NSString *anchorString = [anchorData base64EncodedStringWithOptions:0];

            if (completion) {
                completion(@{
                    @"anchor":  anchorString,
                    @"added":   added,
                    @"deleted": deleted,
                }, nil);
            }
        });
    };

    HKAnchoredObjectQuery *query = [[HKAnchoredObjectQuery alloc]
        initWithType:quantityType
           predicate:predicate
              anchor:anchor
               limit:lim
      resultsHandler:handlerBlock];

    [self.healthStore executeQuery:query];
}
```

- [ ] **Step 2.3 — Commit**
```bash
git add RCTAppleHealthKit/RCTAppleHealthKit+Queries.h RCTAppleHealthKit/RCTAppleHealthKit+Queries.m
git commit -m "feat: add generic fetchAnchoredSamplesOfType for delta queries"
```

---

# TASK 3 — `getDeltaSamples` export + `healthKit:%@:delta` event

**Files:**
- Modify: `RCTAppleHealthKit/RCTAppleHealthKit.m`

- [ ] **Step 3.1 — Add `healthKit:%@:delta` to `supportedEvents` templates (line ~741)**

```objc
// Before:
NSArray *templates = @[@"healthKit:%@:new", @"healthKit:%@:failure", @"healthKit:%@:enabled", @"healthKit:%@:sample", @"healthKit:%@:setup:success", @"healthKit:%@:setup:failure"];

// After:
NSArray *templates = @[@"healthKit:%@:new", @"healthKit:%@:failure", @"healthKit:%@:enabled", @"healthKit:%@:sample", @"healthKit:%@:setup:success", @"healthKit:%@:setup:failure", @"healthKit:%@:delta"];
```

- [ ] **Step 3.2 — Add private helper `startDateFromPeriod:` before `getDeltaSamples`**

```objc
+ (NSDate *)startDateFromPeriod:(NSString *)period {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *now     = [NSDate date];
    if ([period isEqualToString:@"last24hours"]) {
        return [cal dateByAddingUnit:NSCalendarUnitHour  value:-24  toDate:now options:0];
    }
    if ([period isEqualToString:@"today"]) {
        return [cal startOfDayForDate:now];
    }
    if ([period isEqualToString:@"last7days"]) {
        return [cal dateByAddingUnit:NSCalendarUnitDay   value:-7   toDate:now options:0];
    }
    if ([period isEqualToString:@"last30days"]) {
        return [cal dateByAddingUnit:NSCalendarUnitDay   value:-30  toDate:now options:0];
    }
    if ([period isEqualToString:@"last3months"]) {
        return [cal dateByAddingUnit:NSCalendarUnitMonth value:-3   toDate:now options:0];
    }
    if ([period isEqualToString:@"last6months"]) {
        return [cal dateByAddingUnit:NSCalendarUnitMonth value:-6   toDate:now options:0];
    }
    if ([period isEqualToString:@"lastYear"]) {
        return [cal dateByAddingUnit:NSCalendarUnitYear  value:-1   toDate:now options:0];
    }
    return nil;
}
```

- [ ] **Step 3.3 — Add `RCT_EXPORT_METHOD(getDeltaSamples:callback:)` after `getAnchoredWorkouts` (line ~250)**

```objc
RCT_EXPORT_METHOD(getDeltaSamples:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback)
{
    [self _initializeHealthStore];

    NSString *type = [RCTAppleHealthKit stringFromOptions:input key:@"type" withDefault:@""];

    // Workout: delegate to existing anchored workout method unchanged
    if ([type isEqualToString:@"Workout"]) {
        [self workout_getAnchoredQuery:input callback:callback];
        return;
    }

    HKQuantityType *quantityType = (HKQuantityType *)[RCTAppleHealthKit quantityTypeFromName:type];
    if (!quantityType || [quantityType isEqual:[HKObjectType workoutType]]) {
        callback(@[RCTMakeError(@"getDeltaSamples: unsupported type", nil, @{ @"type": type })]);
        return;
    }

    // Unit: caller-supplied → type default
    HKUnit *unit;
    NSString *unitString = [input objectForKey:@"unit"];
    if (unitString.length) {
        @try { unit = [HKUnit unitFromString:unitString]; }
        @catch (NSException *e) { unit = [RCTAppleHealthKit defaultHKUnitForType:type]; }
    } else {
        unit = [RCTAppleHealthKit defaultHKUnitForType:type];
    }

    HKQueryAnchor *anchor = [RCTAppleHealthKit hkAnchorFromOptions:input];
    NSUInteger limit      = [RCTAppleHealthKit uintFromOptions:input key:@"limit" withDefault:HKObjectQueryNoLimit];

    // Date range: explicit startDate wins; period string is the fallback
    NSDate *startDate = [RCTAppleHealthKit dateFromOptions:input key:@"startDate" withDefault:nil];
    NSString *periodString = [input objectForKey:@"period"];
    if (startDate == nil && periodString.length) {
        startDate = [RCTAppleHealthKit startDateFromPeriod:periodString];
    }
    NSDate *endDate = [RCTAppleHealthKit dateFromOptions:input key:@"endDate" withDefault:[NSDate date]];

    NSPredicate *predicate = [RCTAppleHealthKit predicateForAnchoredQueries:anchor startDate:startDate endDate:endDate];

    [self fetchAnchoredSamplesOfType:quantityType
                                unit:unit
                           predicate:predicate
                              anchor:anchor
                               limit:limit
                          completion:^(NSDictionary *results, NSError *error) {
        if (error) {
            callback(@[RCTMakeError(@"getDeltaSamples error", error, nil)]);
            return;
        }
        callback(@[[NSNull null], results]);
    }];
}
```

- [ ] **Step 3.4 — Commit**
```bash
git add RCTAppleHealthKit/RCTAppleHealthKit.m
git commit -m "feat: add getDeltaSamples export and healthKit:<Type>:delta event support"
```

---

# TASK 4 — Upgrade observer: anchor seeding + delta emission

Replaces `setObserverForType:type:bridge:hasListeners:` in Queries.m (line ~1138).

**Files:**
- Modify: `RCTAppleHealthKit/RCTAppleHealthKit+Queries.m`

- [ ] **Step 4.1 — Replace the method body**

Find `- (void)setObserverForType:(HKSampleType *)sampleType type:(NSString *)type bridge:(RCTBridge *)bridge hasListeners:(bool)hasListeners` at line ~1138 and replace the entire method:

```objc
- (void)setObserverForType:(HKSampleType *)sampleType
                      type:(NSString *)type
                    bridge:(RCTBridge *)bridge
              hasListeners:(bool)hasListeners
{
    NSString *deltaEvent        = [NSString stringWithFormat:@"healthKit:%@:delta",         type];
    NSString *newEvent          = [NSString stringWithFormat:@"healthKit:%@:new",           type];
    NSString *failureEvent      = [NSString stringWithFormat:@"healthKit:%@:failure",       type];
    NSString *anchorKey         = [NSString stringWithFormat:@"RNHealth_DeltaAnchor_%@",    type];
    NSString *setupSuccessEvent = [NSString stringWithFormat:@"healthKit:%@:setup:success", type];
    NSString *setupFailureEvent = [NSString stringWithFormat:@"healthKit:%@:setup:failure", type];

    // --- Anchor seeding ---
    // Run a limit:0 anchored query on first registration to capture the current
    // cursor. Without this, the first observer delivery would return all
    // HealthKit history as a "delta".
    BOOL hasStoredAnchor = ([[NSUserDefaults standardUserDefaults] stringForKey:anchorKey] != nil);
    if (!hasStoredAnchor && ![type isEqualToString:@"Workout"]) {
        HKQuantityType *qt = (HKQuantityType *)[RCTAppleHealthKit quantityTypeFromName:type];
        if (qt && ![qt isEqual:[HKObjectType workoutType]]) {
            HKUnit *unit = [RCTAppleHealthKit defaultHKUnitForType:type];
            [self fetchAnchoredSamplesOfType:qt
                                        unit:unit
                                   predicate:nil
                                      anchor:nil
                                       limit:0
                                  completion:^(NSDictionary *results, NSError *error) {
                NSString *seedAnchor = results[@"anchor"];
                if (seedAnchor) {
                    [[NSUserDefaults standardUserDefaults] setObject:seedAnchor forKey:anchorKey];
                    NSLog(@"[HealthKit] Anchor seeded for %@", type);
                }
            }];
        }
    }

    // --- Observer ---
    HKObserverQuery *query = [[HKObserverQuery alloc]
        initWithSampleType:sampleType
                 predicate:nil
             updateHandler:^(HKObserverQuery *query,
                             HKObserverQueryCompletionHandler completionHandler,
                             NSError * _Nullable error) {

        NSLog(@"[HealthKit] Observer fired for %@", type);

        if (error) {
            completionHandler();
            if (self.hasListeners) {
                [self emitEventWithName:failureEvent andPayload:@{}];
            }
            return;
        }

        // Workout: bare :new only (full delta via getDeltaSamples)
        if ([type isEqualToString:@"Workout"]) {
            if (self.hasListeners) {
                [self emitEventWithName:newEvent andPayload:@{}];
            }
            completionHandler();
            return;
        }

        HKQuantityType *quantityType = (HKQuantityType *)[RCTAppleHealthKit quantityTypeFromName:type];
        if (!quantityType || [quantityType isEqual:[HKObjectType workoutType]]) {
            if (self.hasListeners) {
                [self emitEventWithName:newEvent andPayload:@{}];
            }
            completionHandler();
            return;
        }

        // Read stored anchor
        HKQueryAnchor *storedAnchor = nil;
        NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:anchorKey];
        if (stored.length) {
            NSData *anchorData = [[NSData alloc] initWithBase64EncodedString:stored options:0];
            storedAnchor = [NSKeyedUnarchiver unarchiveObjectWithData:anchorData];
        }

        HKUnit *unit = [RCTAppleHealthKit defaultHKUnitForType:type];

        [self fetchAnchoredSamplesOfType:quantityType
                                    unit:unit
                               predicate:nil
                                  anchor:storedAnchor
                                   limit:HKObjectQueryNoLimit
                              completion:^(NSDictionary *results, NSError *fetchError) {

            // Always call completionHandler — HealthKit stops background delivery if omitted
            completionHandler();

            if (fetchError || !results) {
                NSLog(@"[HealthKit] Delta fetch error for %@: %@", type, fetchError.localizedDescription);
                if (self.hasListeners) {
                    [self emitEventWithName:failureEvent andPayload:@{}];
                }
                return;
            }

            // Persist new anchor BEFORE emitting — next delivery starts correctly
            NSString *newAnchorString = results[@"anchor"];
            if (newAnchorString) {
                [[NSUserDefaults standardUserDefaults] setObject:newAnchorString forKey:anchorKey];
            }

            if (self.hasListeners) {
                [self emitEventWithName:deltaEvent andPayload:results];
                // Keep :new for backwards compatibility
                [self emitEventWithName:newEvent andPayload:@{}];
            }
        }];
    }];

    [self.healthStore enableBackgroundDeliveryForType:sampleType
                                            frequency:HKUpdateFrequencyImmediate
                                       withCompletion:^(BOOL success, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[HealthKit] Background delivery setup error for %@: %@", type, error.localizedDescription);
            if (self.hasListeners) {
                [self emitEventWithName:setupFailureEvent andPayload:@{}];
            }
            return;
        }
        NSLog(@"[HealthKit] Background delivery enabled for %@", type);
        [self.healthStore executeQuery:query];
        if (self.hasListeners) {
            [self emitEventWithName:setupSuccessEvent andPayload:@{}];
        }
    }];
}
```

- [ ] **Step 4.2 — Commit**
```bash
git add RCTAppleHealthKit/RCTAppleHealthKit+Queries.m
git commit -m "feat: upgrade observer to emit delta payload with anchor seeding"
```

---

# TASK 5 — `Periods` constant

**Files:**
- Create: `src/constants/Periods.js`
- Modify: `src/constants/index.js`

- [ ] **Step 5.1 — Create `src/constants/Periods.js`**

```js
/**
 * Apple HealthKit query period presets
 * Values match the HealthPeriod type in index.d.ts
 *
 * @type {Object}
 */
export const Periods = {
  last24Hours:  'last24hours',
  today:        'today',
  last7Days:    'last7days',
  last30Days:   'last30days',
  last3Months:  'last3months',
  last6Months:  'last6months',
  lastYear:     'lastYear',
}
```

- [ ] **Step 5.2 — Export from `src/constants/index.js`**

Replace full file content:

```js
import { Activities }  from './Activities'
import { Observers }   from './Observers'
import { Periods }     from './Periods'
import { Permissions } from './Permissions'
import { Units }       from './Units'

export { Activities, Observers, Periods, Permissions, Units }
```

- [ ] **Step 5.3 — Commit**
```bash
git add src/constants/Periods.js src/constants/index.js
git commit -m "feat: add Periods constant for delta query time windows"
```

---

# TASK 6 — JS API

**Files:**
- Modify: `index.js`

- [ ] **Step 6.1 — Update the import at the top of `index.js`**

```js
// Before:
import { Activities, Observers, Permissions, Units } from './src/constants'

// After:
import { Activities, Observers, Periods, Permissions, Units } from './src/constants'
```

- [ ] **Step 6.2 — Add `Periods` to the `Constants` object export in `index.js`**

Find where `Activities`, `Observers`, `Permissions`, `Units` are spread into the exported object and add `Periods`:

```js
Constants: {
  Activities,
  Observers,
  Periods,
  Permissions,
  Units,
},
```

- [ ] **Step 6.3 — Add `getDeltaSamples` after `getAnchoredWorkouts` (line ~39)**

```js
getDeltaSamples: AppleHealthKit.getDeltaSamples,
```

- [ ] **Step 6.4 — Add `getDeltaSamplesForPermissions` JS helper directly after `getDeltaSamples`**

```js
getDeltaSamplesForPermissions: function(requests, callback) {
  if (!requests || requests.length === 0) {
    callback(null, {})
    return
  }
  const results = {}
  let pending = requests.length
  let settled = false

  requests.forEach(function(options) {
    const type = options.type
    AppleHealthKit.getDeltaSamples(options, function(err, result) {
      if (settled) return
      if (err) {
        settled = true
        callback(err, null)
        return
      }
      results[type] = result
      pending -= 1
      if (pending === 0) {
        settled = true
        callback(null, results)
      }
    })
  })
},
```

- [ ] **Step 6.5 — Commit**
```bash
git add index.js
git commit -m "feat: add getDeltaSamples and getDeltaSamplesForPermissions JS API"
```

---

# TASK 7 — TypeScript types

**Files:**
- Modify: `index.d.ts`

- [ ] **Step 7.1 — Add `HealthPeriod` type**

Find `export enum HealthObserver {` (line ~904) and add before it:

```typescript
export type HealthPeriod =
  | 'last24hours'   // rolling: now - 24h → now
  | 'today'         // calendar day: midnight → now
  | 'last7days'
  | 'last30days'
  | 'last3months'
  | 'last6months'
  | 'lastYear'
```

- [ ] **Step 7.2 — Add delta interfaces after `AnchoredQueryResults` (line ~897)**

```typescript
export interface DeletedSample {
  id: string
}

export interface DeltaQueryResult {
  anchor:  string
  added:   HealthValue[]
  deleted: DeletedSample[]
}

export interface DeltaQueryOptions {
  type:       HealthObserver
  anchor?:    string
  unit?:      HealthUnit
  startDate?: string
  endDate?:   string
  period?:    HealthPeriod
  limit?:     number
}
```

- [ ] **Step 7.3 — Add method signatures after `getAnchoredWorkouts` (line ~155)**

```typescript
getDeltaSamples(
  options: DeltaQueryOptions,
  callback: (err: HKErrorResponse, results: DeltaQueryResult) => void,
): void

getDeltaSamplesForPermissions(
  requests: DeltaQueryOptions[],
  callback: (err: HKErrorResponse, results: Record<string, DeltaQueryResult>) => void,
): void
```

- [ ] **Step 7.4 — Update `Constants` interface (line ~9)**

```typescript
export interface Constants {
  Activities:  Record<HealthActivity,   HealthActivity>
  Observers:   Record<HealthObserver,   HealthObserver>
  Periods:     Record<string,           HealthPeriod>
  Permissions: Record<HealthPermission, HealthPermission>
  Units:       Record<HealthUnit,       HealthUnit>
}
```

- [ ] **Step 7.5 — Commit**
```bash
git add index.d.ts
git commit -m "feat: add HealthPeriod, DeltaQueryResult, DeltaQueryOptions TypeScript types"
```

---

# TASK 8 — API docs

**Files:**
- Create: `docs/getDeltaSamples.md`

- [ ] **Step 8.1 — Create the doc**

```markdown
# getDeltaSamples / getDeltaSamplesForPermissions

Fetch only what changed in HealthKit since your last query — added and deleted records.

## Quick reference

| Options | Behaviour |
|---|---|
| `anchor` | Delta since last sync |
| `startDate` / `endDate` | All samples in explicit window |
| `period: 'last3months'` | All samples in last N period |
| `anchor` + `period` | Delta bounded by period window |

## Result shape

```ts
{
  anchor:  string            // Store and pass back on next call
  added:   HealthValue[]     // New or updated samples
  deleted: { id: string }[]  // Deleted sample UUIDs — original data is gone
}
```

## Periods constant

```js
import { Periods } from 'react-native-health'
// last24hours | today | last7days | last30days | last3months | last6months | lastYear
getDeltaSamples({ type: 'HeartRate', period: Periods.last3Months }, cb)
```

## Observer events (reactive mode)

After `initializeBackgroundObservers()`:

```js
emitter.addListener('healthKit:HeartRate:delta', ({ added, deleted, anchor }) => {
  localStore.addSamples(added)
  localStore.removeSamples(deleted.map(d => d.id))
})
```

See full examples in `docs/superpowers/plans/2026-04-14-healthkit-delta-queries.md`.
```

- [ ] **Step 8.2 — Commit**
```bash
git add docs/getDeltaSamples.md
git commit -m "docs: add getDeltaSamples API documentation"
```

---

# TASK 9 — mobileapp-core: wire `HealthKitProvider` anchor path

Blocked on Tasks 1–4 shipping. The anchor path replaces the regular sample fetch when `options.anchor` is provided.

**Files:**
- Modify: `mobileapp-core/src/health/providers/HealthKitProvider.ts`
- Modify: `mobileapp-core/src/health/__tests__/HealthKitProvider.test.ts`

- [ ] **Step 9.1 — Replace `fetchSamples` in HealthKitProvider.ts**

Replace the current `fetchSamples` method (lines 83–122):

```typescript
async fetchSamples(
  metric: HealthMetric,
  from: Date,
  to: Date,
  options: FetchSamplesOptions = {}
): Promise<HealthQueryResult> {
  const config = METRIC_REGISTRY[metric]

  // Anchor path: use getDeltaSamples when anchor is present.
  // Returns { added, deleted, anchor } — maps to HealthQueryResult shape.
  if (options.anchor != null) {
    const deltaOptions = {
      type:      config.healthKitType,
      unit:      config.defaultUnit,
      anchor:    options.anchor,
      startDate: from.toISOString(),
      endDate:   to.toISOString(),
      ...(options.limit != null && { limit: options.limit }),
    }

    const raw = await hkCallback<{
      added:   unknown[]
      deleted: { id: string }[]
      anchor:  string
    }>(
      (cb) => (AppleHealthKit as any).getDeltaSamples(deltaOptions, cb),
      { added: [], deleted: [], anchor: options.anchor }
    )

    const samples = raw.added
      .filter((r): r is NonNullable<unknown> => r != null)
      .map((r) => this.mapSample(r, metric, config.returnShape))

    return {
      samples,
      deletedIds: raw.deleted.map((d) => d.id),
      anchor:     raw.anchor,
    }
  }

  // Date-range path (no anchor): existing behaviour unchanged
  const hkOptions = {
    startDate: from.toISOString(),
    endDate:   to.toISOString(),
    ascending: false,
    ...(options.limit != null && { limit: options.limit }),
    ...(options.includeManuallyAdded != null && {
      includeManuallyAdded: options.includeManuallyAdded,
    }),
    unit: config.defaultUnit,
    ...(config.sampleType != null && { type: config.sampleType }),
  }

  const fn = (AppleHealthKit as any)[config.method]
  if (typeof fn !== 'function') {
    throw new Error(
      `HealthKitProvider: no method "${config.method}" on AppleHealthKit for metric "${metric}"`
    )
  }
  const raw = await hkCallback<unknown[]>(
    (cb) => fn.call(AppleHealthKit, hkOptions, cb),
    []
  )

  const samples = raw
    .filter((r): r is NonNullable<unknown> => r != null)
    .map((r) => this.mapSample(r, metric, config.returnShape))

  return { samples, deletedIds: [], anchor: undefined }
}
```

- [ ] **Step 9.2 — Add tests for anchor path in HealthKitProvider.test.ts**

Add to the mock at the top:
```typescript
getDeltaSamples: jest.fn(),
```

Add test suite after existing `fetchSamples` tests:

```typescript
describe('fetchSamples — anchor path (getDeltaSamples)', () => {
  beforeEach(() => {
    getHK().getDeltaSamples.mockImplementation((_opts: any, cb: Function) =>
      cb(null, {
        added: [
          {
            id: 'uuid-delta-1',
            value: 75,
            startDate: '2026-01-02T10:00:00.000+0000',
            endDate:   '2026-01-02T10:00:00.000+0000',
            sourceName: 'Apple Watch',
            sourceId:   'com.apple.watch',
            metadata: {},
          },
        ],
        deleted: [{ id: 'uuid-old-1' }],
        anchor:  'new-anchor-base64',
      })
    )
  })

  it('calls getDeltaSamples when anchor is provided', async () => {
    await provider.fetchSamples(HealthMetric.HeartRate, FROM, TO, {
      anchor: 'existing-anchor',
    })
    expect(getHK().getDeltaSamples).toHaveBeenCalledWith(
      expect.objectContaining({ anchor: 'existing-anchor', type: 'HeartRate' }),
      expect.any(Function)
    )
    expect(getHK().getHeartRateSamples).not.toHaveBeenCalled()
  })

  it('maps added to samples and deleted to deletedIds', async () => {
    const result = await provider.fetchSamples(HealthMetric.HeartRate, FROM, TO, {
      anchor: 'existing-anchor',
    })
    expect(result.samples).toHaveLength(1)
    expect((result.samples[0] as any).value).toBe(75)
    expect(result.deletedIds).toEqual(['uuid-old-1'])
    expect(result.anchor).toBe('new-anchor-base64')
  })

  it('does NOT call getDeltaSamples when no anchor', async () => {
    getHK().getHeartRateSamples.mockImplementation((_o: any, cb: Function) =>
      cb(null, [])
    )
    await provider.fetchSamples(HealthMetric.HeartRate, FROM, TO)
    expect(getHK().getDeltaSamples).not.toHaveBeenCalled()
    expect(getHK().getHeartRateSamples).toHaveBeenCalled()
  })
})
```

- [ ] **Step 9.3 — Run tests**
```bash
cd /Users/gilad.nadav/dev/mobileapp-core
npx jest src/health/__tests__/HealthKitProvider.test.ts --no-coverage
```
Expected: all tests pass.

- [ ] **Step 9.4 — Commit**
```bash
git add src/health/providers/HealthKitProvider.ts src/health/__tests__/HealthKitProvider.test.ts
git commit -m "feat: wire HealthKitProvider anchor path to getDeltaSamples"
```

---

# TASK 10 — mobileapp-core: observer delta listener

Add ability for the app to subscribe to real-time HealthKit delta events using the reactive mode. Exposes a `useHealthDeltaObserver` hook and a `subscribeHealthDelta` function.

**Files:**
- Create: `mobileapp-core/src/health/healthDeltaObserver.ts`
- Create: `mobileapp-core/src/health/__tests__/healthDeltaObserver.test.ts`
- Modify: `mobileapp-core/src/health/index.ts`

- [ ] **Step 10.1 — Create `healthDeltaObserver.ts`**

```typescript
// src/health/healthDeltaObserver.ts
import { useEffect } from 'react'
import { NativeEventEmitter, NativeModules } from 'react-native'

import { METRIC_REGISTRY } from './metricRegistry'
import type { HealthSample } from './types'
import { HealthMetric } from './types'

export interface HealthDeltaEvent {
  added:   HealthSample[]
  deleted: string[]        // UUIDs
  anchor:  string
}

type DeltaListener = (event: HealthDeltaEvent) => void

const emitter = new NativeEventEmitter(NativeModules.AppleHealthKit)

/**
 * Subscribe to real-time HealthKit delta events for a metric.
 * Fires immediately when HealthKit reports a change (add or delete).
 * Returns an unsubscribe function.
 *
 * Requires initializeBackgroundObservers() to have been called at app start.
 */
export function subscribeHealthDelta(
  metric: HealthMetric,
  listener: DeltaListener
): () => void {
  const config    = METRIC_REGISTRY[metric]
  const eventName = `healthKit:${config.healthKitType}:delta`

  const subscription = emitter.addListener(eventName, (raw: any) => {
    listener({
      added:   raw.added   ?? [],
      deleted: (raw.deleted ?? []).map((d: { id: string }) => d.id),
      anchor:  raw.anchor  ?? '',
    })
  })

  return () => subscription.remove()
}

/**
 * React hook. Subscribes to delta events for a metric while mounted.
 * Re-subscribes if metric or listener reference changes.
 */
export function useHealthDeltaObserver(
  metric: HealthMetric,
  listener: DeltaListener
): void {
  useEffect(() => {
    const unsubscribe = subscribeHealthDelta(metric, listener)
    return unsubscribe
  }, [metric, listener])
}
```

- [ ] **Step 10.2 — Write tests**

Create `mobileapp-core/src/health/__tests__/healthDeltaObserver.test.ts`:

```typescript
import { NativeEventEmitter } from 'react-native'
import { renderHook } from '@testing-library/react-hooks'

import { subscribeHealthDelta, useHealthDeltaObserver } from '../healthDeltaObserver'
import { HealthMetric } from '../types'

jest.mock('react-native', () => ({
  NativeModules:   { AppleHealthKit: {} },
  NativeEventEmitter: jest.fn().mockImplementation(() => ({
    addListener: jest.fn().mockReturnValue({ remove: jest.fn() }),
  })),
}))

const getEmitter = () =>
  (NativeEventEmitter as jest.Mock).mock.results[0].value as {
    addListener: jest.Mock
  }

beforeEach(() => jest.clearAllMocks())

describe('subscribeHealthDelta', () => {
  it('subscribes to the correct event name for HeartRate', () => {
    subscribeHealthDelta(HealthMetric.HeartRate, jest.fn())
    expect(getEmitter().addListener).toHaveBeenCalledWith(
      'healthKit:HeartRate:delta',
      expect.any(Function)
    )
  })

  it('calls listener with mapped event shape', () => {
    const listener = jest.fn()
    subscribeHealthDelta(HealthMetric.HeartRate, listener)

    const handler = getEmitter().addListener.mock.calls[0][1]
    handler({
      added:   [{ id: 'u1', value: 72, startDate: 'x', endDate: 'x', unit: 'bpm' }],
      deleted: [{ id: 'u2' }],
      anchor:  'anchor-abc',
    })

    expect(listener).toHaveBeenCalledWith({
      added:   expect.arrayContaining([expect.objectContaining({ id: 'u1' })]),
      deleted: ['u2'],
      anchor:  'anchor-abc',
    })
  })

  it('returns unsubscribe that removes the listener', () => {
    const remove = jest.fn()
    getEmitter().addListener.mockReturnValue({ remove })
    const unsubscribe = subscribeHealthDelta(HealthMetric.HeartRate, jest.fn())
    unsubscribe()
    expect(remove).toHaveBeenCalled()
  })
})

describe('useHealthDeltaObserver', () => {
  it('subscribes on mount and unsubscribes on unmount', () => {
    const remove = jest.fn()
    getEmitter().addListener.mockReturnValue({ remove })
    const listener = jest.fn()

    const { unmount } = renderHook(() =>
      useHealthDeltaObserver(HealthMetric.HeartRate, listener)
    )
    expect(getEmitter().addListener).toHaveBeenCalledWith(
      'healthKit:HeartRate:delta',
      expect.any(Function)
    )
    unmount()
    expect(remove).toHaveBeenCalled()
  })
})
```

- [ ] **Step 10.3 — Run tests**
```bash
cd /Users/gilad.nadav/dev/mobileapp-core
npx jest src/health/__tests__/healthDeltaObserver.test.ts --no-coverage
```
Expected: all tests pass.

- [ ] **Step 10.4 — Export from index.ts**

Add to `mobileapp-core/src/health/index.ts`:

```typescript
export { subscribeHealthDelta, useHealthDeltaObserver } from './healthDeltaObserver'
export type { HealthDeltaEvent } from './healthDeltaObserver'
```

- [ ] **Step 10.5 — Commit**
```bash
git add src/health/healthDeltaObserver.ts src/health/__tests__/healthDeltaObserver.test.ts src/health/index.ts
git commit -m "feat: add subscribeHealthDelta and useHealthDeltaObserver for reactive delta events"
```

---

## Self-review

- [x] Tasks 1 → 2 → 3 → 4 dependency order enforced — `defaultHKUnitForType:` required by `fetchAnchoredSamplesOfType:` required by both `getDeltaSamples` and observer
- [x] Anchor seeded at observer registration (Task 4) — first delivery never dumps history
- [x] `completionHandler()` always called in observer (Task 4) — HealthKit stops background delivery if omitted
- [x] `startDate` wins over `period` (Task 3) — no ambiguity when both passed
- [x] `deletedObjects` properly handled in `fetchAnchoredSamplesOfType:` (Task 2) — fixes the existing silent ignore in `fetchAnchoredWorkouts:` at line 512
- [x] Workout type always delegates to existing `workout_getAnchoredQuery:` — no regression
- [x] `healthKit:<Type>:new` still fires alongside `:delta` — backwards compatible
- [x] Tasks 9 and 10 are blocked on Tasks 1–4 — stated explicitly
- [x] `getDeltaSamplesForPermissions` uses `settled` guard — no double callback
- [x] `mobileapp-core` already has `HealthPeriod`, `resolveDateRange`, `deletedIds`, `anchor` fields — no duplication needed, Tasks 9/10 just wire them up
- [x] `useHealthDeltaObserver` returns cleanup — no memory leaks

---

## Jira tickets

### Ticket 1 — react-native-health SDK (Tasks 1–8)

```
Title: [SDK] Add HealthKit delta query support (getDeltaSamples + observer delta events)
Type: Feature | Component: react-native-health

Summary:
Add delta (anchored) query support to the SDK so consuming apps can sync only what
changed in HealthKit — added and deleted records — without re-fetching all data.

Currently the SDK has two problems:
1. Background observers emit empty payload, forcing full re-fetch on every change.
2. There is no way to know which records were deleted.

Solution — two modes backed by HKAnchoredObjectQuery:

Reactive: initializeBackgroundObservers() seeds anchor per type (no historical dump).
On change: runs anchored query → emits healthKit:<Type>:delta with { added, deleted, anchor }.
Anchor persisted in NSUserDefaults per type.

Proactive: new getDeltaSamples(options, callback).
Supports anchor, startDate/endDate, period string, or anchor+period.
New Periods constant (last24hours/today/last7days/last30days/last3months/last6months/lastYear).
getDeltaSamplesForPermissions for parallel multi-type fetch.

Acceptance criteria:
- healthKit:<Type>:delta fires with non-empty added/deleted on HealthKit change
- First observer delivery after initializeBackgroundObservers() contains no historical data
- getDeltaSamples({ type, anchor }) returns only changes since anchor
- getDeltaSamples({ type, period: 'last3months' }) returns samples from last 3 months
- deleted array contains UUID of deleted samples
- healthKit:<Type>:new still fires (backwards compat)
- getAnchoredWorkouts behaviour unchanged
- TypeScript types exported for all new interfaces

Implementation plan: docs/superpowers/plans/2026-04-14-healthkit-delta-queries.md (Tasks 1–8)
```

### Ticket 2 — mobileapp-core anchor path (Task 9)

```
Title: [Health] Wire HealthKitProvider.fetchSamples to use getDeltaSamples when anchor present
Type: Feature | Component: mobileapp-core health module
Depends on: Ticket 1

Summary:
HealthKitProvider.fetchSamples currently ignores options.anchor (explicit TODO at line 102).
Wire it up: when anchor is provided, call AppleHealthKit.getDeltaSamples instead of the
regular method. Map added → samples, deleted → deletedIds, anchor → anchor on the result.

This unblocks queryHealth({ metric, anchor }) returning real deleted IDs and updated anchors
instead of always returning deletedIds: [] and anchor: undefined.

Acceptance criteria:
- fetchSamples with anchor calls getDeltaSamples, not the type-specific method
- fetchSamples without anchor continues using existing type-specific method (no regression)
- result.deletedIds populated from delta deleted UUIDs
- result.anchor populated from delta new anchor
- All existing HealthKitProvider tests still pass
- New anchor-path tests added

Implementation plan: docs/superpowers/plans/2026-04-14-healthkit-delta-queries.md (Task 9)
```

### Ticket 3 — mobileapp-core reactive observer (Task 10)

```
Title: [Health] Add subscribeHealthDelta and useHealthDeltaObserver for reactive HealthKit sync
Type: Feature | Component: mobileapp-core health module
Depends on: Ticket 1

Summary:
No mechanism currently exists in mobileapp-core to react to HealthKit changes in real time.
Add subscribeHealthDelta(metric, listener) and useHealthDeltaObserver(metric, listener) hook
that listen to the healthKit:<Type>:delta events emitted by the upgraded observer.

This allows features to immediately update their local state when the user adds or deletes
health data, without polling or manual re-fetch triggers.

Acceptance criteria:
- subscribeHealthDelta subscribes to correct event name per metric
- Listener receives { added: HealthSample[], deleted: string[], anchor: string }
- unsubscribe function removes the listener
- useHealthDeltaObserver unsubscribes on unmount
- Exported from mobileapp-core health module index

Implementation plan: docs/superpowers/plans/2026-04-14-healthkit-delta-queries.md (Task 10)
```
