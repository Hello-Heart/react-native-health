/**
 * Minimum time between background delta fetches for HealthKit observers.
 * Pass to configureBackgroundSync({ syncInterval }).
 * Default when omitted: every24Hours.
 *
 * @type {Object}
 */
export const SyncIntervals = {
  every1Hour:   'every1hour',
  every6Hours:  'every6hours',
  every12Hours: 'every12hours',
  every24Hours: 'every24hours',
  every48Hours: 'every48hours',
  everyWeek:    'everyweek',
}
