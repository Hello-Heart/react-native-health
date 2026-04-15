# react-native-health — Project Guide

## What This Project Is

A React Native bridge library that exposes **Apple HealthKit** to JavaScript/TypeScript. It lets iOS apps read and write health and fitness data — steps, heart rate, workouts, blood pressure, sleep, nutrition, clinical records, and 100+ other data types — through a JavaScript API.

**iOS only.** Returns an empty object on non-iOS platforms.

---

## Architecture

```
react-native-health/
├── index.js                          # Main entry point; exports the AppleHealthKit object
├── index.d.ts                        # TypeScript type definitions (~950 lines)
├── src/constants/                    # JS constants: Permissions, Activities, Units, Observers
├── RCTAppleHealthKit/                # Native iOS layer (Objective-C)
│   ├── RCTAppleHealthKit.h/m         # Core bridge module, HKHealthStore init
│   ├── RCTAppleHealthKit+Methods_*.m # Domain-specific categories (Body, Vitals, Fitness…)
│   ├── RCTAppleHealthKit+Queries.h   # HKQuery interface definitions
│   ├── RCTAppleHealthKit+TypesAndPermissions.h  # Permission mapping (string → HK type)
│   └── RCTAppleHealthKit+Utils.h     # Helper utilities
├── app.plugin.js                     # Expo Config Plugin (auto-configures Info.plist + entitlements)
├── docs/                             # Per-method API documentation
└── example/                         # Sample React Native app
```

### Layer Breakdown

| Layer | Technology | Responsibility |
|-------|-----------|----------------|
| JS/TS | `index.js`, `index.d.ts` | Public API, type definitions |
| Constants | `src/constants/` | Permission names, activity types, units |
| Native bridge | `RCTAppleHealthKit.m` | HealthKit store, permission request, event emitter |
| Domain categories | `+Methods_*.m` files | CRUD operations per health data domain |
| Expo plugin | `app.plugin.js` | Manages Info.plist and entitlements for Expo users |

---

## Key Patterns

### Callback-based API
All methods use Node-style `callback(error, result)` — no Promises. This follows early React Native conventions.

```js
AppleHealthKit.getHeartRateSamples(options, (err, results) => { ... })
```

### Permission model
Permissions are requested at init time with separate read/write arrays. Clinical health record access requires an additional entitlement.

```js
AppleHealthKit.initHealthKit({ permissions: { read: ['HeartRate'], write: ['Steps'] } }, callback)
```

### Domain categories (Objective-C)
Native code is split across 14+ category files (`+Methods_Body`, `+Methods_Vitals`, `+Methods_Dietary`, etc.) to keep each file focused.

### Background observers
Extends `RCTEventEmitter` to emit events (e.g. `"healthKit:HeartRate:new"`) when HealthKit data changes — used for long-running background monitoring.

---

## Health Data Domains Covered

| Domain | Examples |
|--------|---------|
| Body metrics | Weight, height, BMI, body fat %, waist circumference |
| Vitals | Heart rate, ECG, blood pressure, SpO2, respiratory rate, HRV, VO2 max |
| Activity | Steps, distance, flights climbed, active/basal energy, exercise time, stand time |
| Workouts | Save/query workouts; route GPS data; anchored queries |
| Dietary | Water, calories, protein, carbs, fat, fiber; `saveFood` composite entries |
| Lab tests | Blood glucose, blood alcohol, insulin delivery |
| Clinical records | FHIR-based: medications, conditions, allergies, immunizations, procedures, labs |
| Sleep | Sleep stage samples |
| Mindfulness | Mindful session save/query |
| Hearing | Environmental and headphone audio exposure |
| Characteristics | Biological sex, date of birth, blood type |

---

## TypeScript

`index.d.ts` exports:
- `AppleHealthKit` — the main module with 120+ typed method signatures
- `HealthKitPermissions` — `{ read: HealthPermission[], write: HealthPermission[] }`
- `HealthValue`, `BaseValue`, `HealthInputOptions`, `HealthValueOptions` — common query/save interfaces
- Enums: `HealthPermission`, `HealthActivity`, `HealthUnit`, `HealthObserver`, `ClinicalRecordType`
- Specialized interfaces for ECG, heartbeat series, workouts, routes, activity summaries, clinical records

---

## Native iOS Details

- Uses `HKHealthStore` for all HealthKit access
- Query types used: `HKSampleQuery`, `HKStatisticsQuery`, `HKAnchoredObjectQuery`, `HKWorkoutQuery`
- String constants from JS are mapped to native `HKObjectType` instances in `RCTAppleHealthKit+TypesAndPermissions.h`
- CocoaPods spec: `RNAppleHealthKit.podspec`

---

## Development Notes

- **Node >= 16** required
- **React Native >= 0.67.3** peer dependency
- The codebase is written in **Objective-C**; a migration to Swift is noted as in-progress in the README
- The library accepts critical bug fixes; feature PRs reviewed selectively
- Expo users configure the library via `app.plugin.js`; bare RN users configure Info.plist and entitlements manually

---

## Documentation

All API methods have dedicated docs in `docs/`. Key reference files:

| File | Contents |
|------|---------|
| `docs/README.md` | Full API index with links to every method |
| `docs/Installation.md` | Setup for bare React Native |
| `docs/Expo.md` | Expo-specific setup |
| `docs/permissions.md` | All available `HealthPermission` constants |
| `docs/units.md` | All available `HealthUnit` constants |
| `docs/activities.md` | All available `HealthActivity` workout types |
| `docs/observers.md` + `docs/background.md` | Background observer setup and usage |
| `docs/initHealthKit.md` | Permission request and initialization |
| `docs/<methodName>.md` | Per-method signature, options, and example (90+ files) |

When looking up how a method works, check `docs/<methodName>.md` first — each file includes the options object shape, callback result shape, and a usage example.

---

## Common Entry Points When Making Changes

| Task | Where to look |
|------|--------------|
| Add a new health data type | `src/constants/Permissions.js` + new method in `index.js` + matching `+Methods_*.m` category + type in `index.d.ts` |
| Fix a query bug | `RCTAppleHealthKit+Methods_<Domain>.m` and `RCTAppleHealthKit+Queries.h` |
| Fix a permission issue | `RCTAppleHealthKit+TypesAndPermissions.h`, `RCTAppleHealthKit.m` |
| Add Expo config option | `app.plugin.js` |
| Update TypeScript types | `index.d.ts` |
