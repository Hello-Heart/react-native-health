# deleteCholesterolSample

Delete a cholesterol sample from HealthKit.

`deleteCholesterolSample` accepts the UUID string of a previously saved cholesterol sample and a callback:

Example input:

```javascript
let id = "ba13089a-a311-4ffe-9352-f5c568936f16"
```

Example usage:

```javascript
AppleHealthKit.deleteCholesterolSample(
  id,
  (err, result) => {
    if (err) {
      console.log('error deleting cholesterol sample: ', err)
      return
    }
    // result is the number of records deleted
    console.log('deleted:', result)
  },
)
```

Example output (1 if deleted):

```json
1
```
