# getCholesterolSamples

Query for dietary cholesterol samples. The options object is used to set up a query to retrieve relevant samples.

Example input options:

```javascript
let options = {
  startDate: new Date(2021, 0, 0).toISOString(), // required
  endDate: new Date().toISOString(), // optional; default now
  ascending: false, // optional; default false
  limit: 10, // optional; default no limit
}
```

```javascript
AppleHealthKit.getCholesterolSamples(
  options,
  (err, results) => {
    if (err) {
      console.log('error getting cholesterol samples: ', err)
      return
    }
    console.log(results)
  },
)
```

Example output:

```json
[
  {
    "id": "5013eca7-4aee-45af-83c1-dbe3696b2e51",
    "endDate": "2021-03-22T16:21:00.000-0300",
    "sourceId": "com.apple.Health",
    "sourceName": "Health",
    "startDate": "2021-03-22T16:21:00.000-0300",
    "value": 150,
    "metadata": {
      "HKWasUserEntered": true
    }
  }
]
```

Values are returned in milligrams (mg) by default.
