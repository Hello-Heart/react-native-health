/* eslint-env jest */
const rn = require('react-native');

// Mock native HealthKit module — not available in Jest environment
const handler = {get: () => jest.fn()};
rn.NativeModules.AppleHealthKit = new Proxy({}, handler);

// Eagerly resolve NativeEventEmitter so it's in the require cache before
// react-test-renderer's scheduler fires useEffect after Jest teardown.
rn.NativeEventEmitter; // noqa — side-effect: caches module before teardown
