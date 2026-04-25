# saveCholesterolSample

Save a dietary cholesterol sample to HealthKit.

`saveCholesterolSample` accepts an options object containing a numeric value and optional unit, date, and metadata:

Example input options:

```javascript
let options = {
  value: 150,
  unit: 'mg', // optional; default milligrams
  date: new Date().toISOString(), // optional; default now
  metadata: {
    HKWasUserEntered: true,
  }, // optional
}
```

Call the method:

```javascript
AppleHealthKit.saveCholesterolSample(
  options,
  (err, result) => {
    if (err) {
      console.log('error saving cholesterol to HealthKit: ', err)
      return
    }
    // result is the UUID string of the saved sample
    console.log('saved cholesterol sample:', result)
  },
)
```

Example output (the saved record's UUID):

```json
"ba13089a-a311-4ffe-9352-f5c568936f16"
```
