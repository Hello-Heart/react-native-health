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

## Proactive mode — fetch on demand

App manages the anchor in AsyncStorage:

```js
import AsyncStorage from '@react-native-async-storage/async-storage'
import AppleHealthKit from 'react-native-health'

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

## Periods constant

```js
import { Periods } from 'react-native-health'
// last24hours | today | last7days | last30days | last3months | last6months | lastYear

AppleHealthKit.getDeltaSamples(
  { type: 'HeartRate', unit: 'bpm', period: Periods.last3Months },
  (err, { added, deleted, anchor }) => { /* ... */ }
)
```

## Multi-type fetch

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

## Reactive mode — observer events

After `initializeBackgroundObservers()`, HealthKit pushes deltas automatically:

```js
import { NativeModules, NativeEventEmitter } from 'react-native'

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
- First delivery only contains data added/deleted **after** observer registration (anchor seeded at setup)
- Each delivery contains only what changed since the previous delivery
- Deletions carry UUID only — HealthKit discards original values on delete
- `healthKit:<Type>:new` still fires alongside `:delta` for backwards compatibility

## Options

| Option | Type | Description |
|---|---|---|
| `type` | `HealthObserver` | HealthKit data type (e.g. `'HeartRate'`) |
| `unit` | `HealthUnit` | Unit for values. Falls back to type default if omitted |
| `anchor` | `string` | Opaque cursor from previous call. If omitted, fetches all matching |
| `startDate` | `string` | ISO 8601. Lower bound for the query window |
| `endDate` | `string` | ISO 8601. Upper bound. Defaults to now |
| `period` | `HealthPeriod` | Preset window (`last7days`, `last3months`, etc.) Used if `startDate` is omitted |
| `limit` | `number` | Max samples to return. Default: no limit |
