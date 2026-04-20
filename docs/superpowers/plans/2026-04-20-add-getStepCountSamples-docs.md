# Add getStepCountSamples Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create API documentation for the `getStepCountSamples` method and update the README index to include it.

**Architecture:** Two simple tasks: (1) Create method documentation following the existing pattern from `getDailyStepCountSamples.md`, (2) Update the README.md Fitness Methods section to list the new method in alphabetical order.

**Tech Stack:** Markdown documentation

---

## Task 1: Create getStepCountSamples.md documentation

**Files:**
- Create: `docs/getStepCountSamples.md`

- [ ] **Step 1: Create the documentation file with method description and options**

Create file `docs/getStepCountSamples.md` with the following content:

```markdown
# getStepCountSamples

Query for step count samples over a specified date range. Each sample represents individual step count data points. Use this for detailed per-sample data; use `getDailyStepCountSamples` for aggregated daily totals.

Example input options:

```javascript
let options = {
    startDate: (new Date(2016,1,1)).toISOString(), // required
    endDate:   (new Date()).toISOString(), // optional; default now
    unit: 'count', // optional; default 'count'
    ascending: false, // optional; default false
    limit: 10, // optional; default no limit
};
```

Call the method:

```javascript
AppleHealthKit.getStepCountSamples(
  (options: HealthInputOptions),
  (err: Object, results: Array<Object>) => {
    if (err) {
      return
    }
    console.log(results)
  },
)
```

Example output, value is in count unit:

```json
[
  {
    "endDate": "2021-03-22T17:00:00.000-0300",
    "startDate": "2021-03-22T16:00:00.000-0300",
    "value": 1234,
    "metadata": [
      {
        "sourceId": "com.apple.Health",
        "sourceName": "Health",
        "quantity": 1234
      }
    ]
  }
]
```
```

- [ ] **Step 2: Verify file was created**

Run: `ls -la docs/getStepCountSamples.md`

Expected: File exists with content

---

## Task 2: Update README.md to add getStepCountSamples to Fitness Methods section

**Files:**
- Modify: `docs/README.md` (Fitness Methods section, line 66-80)

- [ ] **Step 1: Add getStepCountSamples to Fitness Methods section in alphabetical order**

In `docs/README.md`, find the "### Fitness Methods" section (around line 66) and add the new method in alphabetical order. The section currently has:

```markdown
### Fitness Methods

- [getDailyStepCountSamples](getDailyStepCountSamples.md)
- [getStepCount](getStepCount.md)
- [getSamples](getSamples.md)
- ...
```

Change it to:

```markdown
### Fitness Methods

- [getDailyStepCountSamples](getDailyStepCountSamples.md)
- [getStepCount](getStepCount.md)
- [getStepCountSamples](getStepCountSamples.md)
- [getSamples](getSamples.md)
- ...
```

(The new entry goes between `getStepCount` and `getSamples` to maintain alphabetical order)

- [ ] **Step 2: Verify the change**

Run: `grep -A 5 "### Fitness Methods" docs/README.md`

Expected: Output shows `getStepCountSamples` listed in alphabetical order with link to `getStepCountSamples.md`

---

## Verification Checklist

- [ ] `docs/getStepCountSamples.md` exists and contains proper documentation
- [ ] `docs/README.md` includes `getStepCountSamples` in Fitness Methods section in alphabetical order
- [ ] Documentation format matches existing method docs (description, options, call example, output example)
- [ ] All changes committed together
