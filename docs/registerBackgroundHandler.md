# registerBackgroundHandler

Opt in to the UIBackgroundTask + Headless JS upload fence for HealthKit background observers.

## Signature

```javascript
AppleHealthKit.registerBackgroundHandler(registered)
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `registered` | `boolean` | Yes | `true` to opt in; `false` to opt out (default behaviour) |

## Description

When `true`, each HealthKit background-observer wake:

1. Opens a `UIBackgroundTask` fence before the HK anchor fetch begins.
2. Fetches the delta samples.
3. Launches a `HealthBackgroundSync` Headless JS Task, passing the samples as the task data.
4. Defers `completionHandler()` (and anchor advancement in `NSUserDefaults`) until JS calls `completeHealthTask(taskId)`.

When `false` (the default), the observer takes the existing path: `completionHandler()` is called immediately after the fetch completes, as before this feature was added.

**Requirements:**

- Register a Headless JS task named `HealthBackgroundSync` via `AppRegistry.registerHeadlessTask` before calling this method.
- **New Architecture (RN 0.74+ bridgeless mode):** Headless JS is not supported in bridgeless mode. Do not use this method with bridgeless RN.
- iOS only.

## Example

```javascript
import { AppRegistry } from 'react-native'
import AppleHealthKit from 'react-native-health'

AppRegistry.registerHeadlessTask('HealthBackgroundSync', () => async (data) => {
  const { taskId, metric, samples } = data
  try {
    await uploadSamples(metric, samples)
  } finally {
    AppleHealthKit.completeHealthTask(taskId)
  }
})

// Call once at app startup, after registering the headless task above
AppleHealthKit.registerBackgroundHandler(true)
```

## See Also

- [`completeHealthTask`](completeHealthTask.md)
- [`configureBackgroundSync`](configureBackgroundSync.md)
- [Background Observer Setup](background.md)
