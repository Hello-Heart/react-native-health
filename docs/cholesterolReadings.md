# cholesterolReadings

Read blood lipid cholesterol panel readings from HealthKit lab result records.

Returns structured panels parsed from FHIR `LabResultRecord` clinical data. Each panel represents one cholesterol blood draw grouped by source and date.

**Requires:** Health Records (`com.apple.developer.healthkit.clinical-records`) entitlement and `LabResultRecord` read permission. iOS 12+.

## Usage

```js
import AppleHealthKit from 'react-native-health'

AppleHealthKit.cholesterolReadings(
  {
    startDate: new Date(2020, 0, 1).toISOString(),
    endDate: new Date().toISOString(),
    limit: 10,
    ascending: false,
  },
  (err, results) => {
    if (err) return console.log(err)
    console.log(results)
  }
)
```

## Options

| Key | Type | Required | Default | Description |
|-----|------|----------|---------|-------------|
| `startDate` | ISO 8601 string | Yes | — | Start of query range |
| `endDate` | ISO 8601 string | No | now | End of query range |
| `limit` | number | No | no limit | Maximum panels to return |
| `ascending` | boolean | No | `false` | Sort order by `startDate` |

## Response

Array of `CholesterolPanel` objects. Panels without a `total` value are excluded.

| Field | Type | Required | Unit | Description |
|-------|------|----------|------|-------------|
| `id` | string | No | — | HealthKit sample UUID |
| `startDate` | string | Yes | ISO 8601 | Panel sample date |
| `endDate` | string | Yes | ISO 8601 | Panel sample end date |
| `sourceName` | string | Yes | — | Health institution name |
| `sourceId` | string | Yes | — | Source bundle identifier |
| `total` | number | Yes | mg/dL | Total cholesterol |
| `ldl` | number | No | mg/dL | LDL cholesterol |
| `hdl` | number | No | mg/dL | HDL cholesterol |
| `triglycerides` | number | No | mg/dL | Triglycerides |

## LOINC Codes

| Field | Codes matched |
|-------|--------------|
| `total` | 2093-3 |
| `ldl` | 2089-1, 18262-6, 13457-7 |
| `hdl` | 2085-9 |
| `triglycerides` | 2571-8 |

## Delta / incremental sync

Use `getDeltaSamples` with `type: 'CholesterolReadings'` for incremental sync:

```js
AppleHealthKit.getDeltaSamples(
  { type: 'CholesterolReadings', anchor: savedAnchor },
  (err, results) => {
    if (err) return console.log(err)
    const { anchor, added, deleted } = results
    // anchor: save for next call
    // added: CholesterolPanel[] — individual observations (may be partial panels)
    // deleted: [{ id }]
  }
)
```

Note: In delta mode, each `added` item represents one individual observation that changed — it may contain only one of `total`, `ldl`, `hdl`, or `triglycerides`.
