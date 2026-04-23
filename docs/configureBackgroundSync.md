# configureBackgroundSync

Configure the minimum interval between background delta fetches. Call this once after `initHealthKit` to opt into background sync.

## Signature

```js
AppleHealthKit.configureBackgroundSync(options, callback)
```

## Options

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | `boolean` | `true` | Enable or disable background sync |
| `syncInterval` | `SyncInterval` | `'every24hours'` | Minimum time between delta fetches |

`SyncInterval` values: `'every1hour'`, `'every6hours'`, `'every12hours'`, `'every24hours'`, `'every48hours'`, `'everyweek'`

## Example

```js
import AppleHealthKit from 'react-native-health'

AppleHealthKit.configureBackgroundSync(
  { enabled: true, syncInterval: 'every6hours' },
  (err) => {
    if (err) console.error('configureBackgroundSync error:', err)
  }
)
```

## Notes

- This only controls the minimum interval enforced in native code. HealthKit itself decides when to wake the app in the background.
- If never called, background sync is disabled by default (opt-in behaviour).
- Call `setObserver` for each type you want to receive delta events for.
