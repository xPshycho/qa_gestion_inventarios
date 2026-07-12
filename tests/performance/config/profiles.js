const LOAD_STAGES = [
  { duration: __ENV.K6_LOAD_RAMP_UP || '20s', target: Number(__ENV.K6_LOAD_INITIAL_VUS || 5) },
  { duration: __ENV.K6_LOAD_STEADY || '1m', target: Number(__ENV.K6_LOAD_INITIAL_VUS || 5) },
  { duration: __ENV.K6_LOAD_PEAK || '20s', target: Number(__ENV.K6_LOAD_MAX_VUS || 10) },
  { duration: __ENV.K6_LOAD_RAMP_DOWN || '20s', target: 0 },
];

export const profiles = {
  smoke: {
    executor: 'constant-vus',
    vus: Number(__ENV.K6_SMOKE_VUS || 1),
    duration: __ENV.K6_SMOKE_DURATION || '30s',
    gracefulStop: '10s',
  },
  load: {
    executor: 'ramping-vus',
    stages: LOAD_STAGES,
    gracefulRampDown: '10s',
    gracefulStop: '10s',
  },
};

export function resolveProfile(profileName) {
  const normalized = String(profileName || 'smoke').toLowerCase();
  const profile = profiles[normalized];

  if (!profile) {
    throw new Error(`K6_PROFILE must be one of: ${Object.keys(profiles).join(', ')}`);
  }

  return {
    name: normalized,
    scenario: profile,
  };
}
