# completeHealthTask

Signal that the JS headless upload for a given task is complete, releasing the UIBackgroundTask fence and advancing the HealthKit anchor.

## Signature

```javascript
AppleHealthKit.completeHealthTask(taskId)
```

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `taskId` | `number` | Yes | The task ID from the `HealthBackgroundSync` headless task payload |

## Description

Must be called in the `finally` block of every `HealthBackgroundSync` Headless JS Task handler - on both success and error paths. When called:

1. The HealthKit anchor for this metric is persisted to `NSUserDefaults`.
2. The HealthKit `completionHandler()` fires, confirming successful delivery to iOS.
3. The `UIBackgroundTask` fence ends, returning background time to the OS.

If `completeHealthTask` is not called before iOS expiry (~30 s), the OS expiry handler calls it internally. The anchor still advances on expiry, but any in-flight upload will have been terminated.

## Example

```javascript
AppRegistry.registerHeadlessTask('HealthBackgroundSync', () => async (data) => {
  const { taskId, metric, samples, anchor } = data
  try {
    await uploadSamples(metric, samples)
  } finally {
    // Always call - in both success and error paths
    AppleHealthKit.completeHealthTask(taskId)
  }
})
```

## See Also

- [`registerBackgroundHandler`](registerBackgroundHandler.md)
- [Background Observer Setup](background.md)
