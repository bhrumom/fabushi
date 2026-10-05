import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const desktopRoot = path.resolve(new URL('..', import.meta.url).pathname);
const config = JSON.parse(await readFile(path.join(desktopRoot, 'e2e/fixtures/avatar-motion-parity.v1.json'), 'utf8'));
const evidenceRoot = path.resolve(process.env.GBF509_EVIDENCE_DIR || path.join(desktopRoot, 'test-results/gbf-509-motion-parity'));
const raw = JSON.parse(await readFile(path.join(evidenceRoot, 'raw-motion-capture.json'), 'utf8'));
const traces = raw.capture;

function mean(values) { return values.length ? values.reduce((sum, v) => sum + v, 0) / values.length : 0; }
function median(values) {
  if (!values.length) return 0;
  const s = [...values].sort((a, b) => a - b); const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}
function percentile(values, p) {
  if (!values.length) return 1;
  const s = [...values].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.max(0, Math.floor((s.length - 1) * p)))];
}
function mae(a, b) {
  const n = Math.min(a.length, b.length); if (!n) return Infinity;
  let sum = 0; for (let i = 0; i < n; i += 1) sum += Math.abs(Number(a[i]) - Number(b[i]));
  return sum / n;
}
function relativeError(reference, actual, floor = 1e-6) {
  return Math.abs(Number(actual) - Number(reference)) / Math.max(Math.abs(Number(reference)), floor);
}
function pearson(a, b) {
  const n = Math.min(a.length, b.length); if (n < 3) return 0;
  const aa = a.slice(0, n), bb = b.slice(0, n), ma = mean(aa), mb = mean(bb);
  let top = 0, da = 0, db = 0;
  for (let i = 0; i < n; i += 1) {
    const xa = aa[i] - ma, xb = bb[i] - mb;
    top += xa * xb; da += xa * xa; db += xb * xb;
  }
  return top / Math.sqrt(Math.max(1e-12, da * db));
}
function dominantPeriod(samples, field) {
  if (samples.length < 30) return null;
  const start = samples[0].t, end = samples[samples.length - 1].t;
  let best = null;
  for (let period = 1000; period <= Math.min(10000, end - start); period += 50) {
    const center = mean(samples.map((x) => Number(x[field])));
    let sin = 0, cos = 0;
    for (const sample of samples) {
      const phase = 2 * Math.PI * (sample.t - start) / period;
      const value = Number(sample[field]) - center;
      sin += value * Math.sin(phase); cos += value * Math.cos(phase);
    }
    const power = sin * sin + cos * cos;
    if (!best || power > best.power) best = { periodMs: period, power };
  }
  return best?.periodMs ?? null;
}
function normalizedEyes(samples) {
  const l = Math.max(0.01, percentile(samples.map((x) => Number(x.leftEyePx)), 0.9));
  const r = Math.max(0.01, percentile(samples.map((x) => Number(x.rightEyePx)), 0.9));
  return { left: samples.map((x) => Number(x.leftEyePx) / l), right: samples.map((x) => Number(x.rightEyePx) / r) };
}
function blinkEvents(samples) {
  const eyes = normalizedEyes(samples), out = []; let start = null;
  for (let i = 0; i < samples.length; i += 1) {
    const closed = (eyes.left[i] + eyes.right[i]) / 2 < 0.45;
    if (closed && start == null) start = samples[i].t;
    if (!closed && start != null) { out.push({ at: start, durationMs: samples[i].t - start }); start = null; }
  }
  return out;
}
function firstPeak(samples, field, eventAt, windowMs = 850) {
  const pre = samples.filter((x) => x.t < eventAt).slice(-6);
  const base = mean(pre.map((x) => Number(x[field])));
  const candidates = samples.filter((x) => x.t >= eventAt && x.t <= eventAt + windowMs);
  let best = null;
  for (const x of candidates) {
    const value = Number(x[field]) - base, score = Math.abs(value);
    if (!best || score > best.score) best = { timeMs: x.t - eventAt, value, score };
  }
  return best;
}
function settling(samples, field, eventAt, fraction = 0.12) {
  const after = samples.filter((x) => x.t >= eventAt); if (after.length < 10) return null;
  const tail = after.slice(-8), target = mean(tail.map((x) => Number(x[field])));
  const peak = Math.max(0.01, ...after.map((x) => Math.abs(Number(x[field]) - target)));
  const limit = peak * fraction;
  for (let i = 0; i < after.length - 5; i += 1) {
    if (after.slice(i, i + 6).every((x) => Math.abs(Number(x[field]) - target) <= limit)) return after[i].t - eventAt;
  }
  return after[after.length - 1].t - eventAt;
}
function reboundPeriod(samples, field, eventAt) {
  const pre = samples.filter((x) => x.t < eventAt).slice(-6), base = mean(pre.map((x) => Number(x[field])));
  const after = samples.filter((x) => x.t >= eventAt), minima = [];
  for (let i = 1; i < after.length - 1; i += 1) {
    const a = Number(after[i - 1][field]) - base, b = Number(after[i][field]) - base, c = Number(after[i + 1][field]) - base;
    if (b < a && b <= c && b < -0.03) minima.push(after[i].t);
  }
  return minima.length >= 2 ? minima[1] - minima[0] : null;
}
function energyShape(values, intervalMs) {
  if (!values.length) return { peakMs: null, durationMs: null, peak: 0 };
  const peak = Math.max(...values), peakIndex = values.indexOf(peak), threshold = peak * 0.12;
  let last = peakIndex; for (let i = peakIndex; i < values.length; i += 1) if (values[i] >= threshold) last = i;
  return { peakMs: (peakIndex + 1) * intervalMs, durationMs: (last + 1) * intervalMs, peak };
}

const checks = [];
function check(name, value, limit, pass, extra = {}) { checks.push({ name, value, limit, pass: Boolean(pass), ...extra }); }

const idle = traces.idle;
const refIdlePeriod = dominantPeriod(idle.reference, 'bodyY');
const fabIdlePeriod = dominantPeriod(idle.fabushi, 'bodyY');
const idlePeriodError = refIdlePeriod && fabIdlePeriod ? relativeError(refIdlePeriod, fabIdlePeriod) : Infinity;
check('idle.bodyY.period.relativeError', idlePeriodError, config.thresholds.bodyY.periodRelativeErrorMax, idlePeriodError <= config.thresholds.bodyY.periodRelativeErrorMax, { referenceMs: refIdlePeriod, fabushiMs: fabIdlePeriod });
const idleRollMae = mae(idle.reference.map((x) => x.roll), idle.fabushi.map((x) => x.roll));
check('idle.roll.maeDeg', idleRollMae, config.thresholds.roll.ambientMaeDegMax, idleRollMae <= config.thresholds.roll.ambientMaeDegMax);
const idleSquashMae = mae(idle.reference.map((x) => x.squash), idle.fabushi.map((x) => x.squash));
check('idle.squash.mae', idleSquashMae, config.thresholds.squash.maeMax, idleSquashMae <= config.thresholds.squash.maeMax);

const curious = traces['curious-nod'];
const preNodRef = curious.reference.filter((x) => x.t < 1600), preNodFab = curious.fabushi.filter((x) => x.t < 1600);
const curiousRollMae = mae(preNodRef.map((x) => x.roll), preNodFab.map((x) => x.roll));
check('curious.roll.maeDeg', curiousRollMae, config.thresholds.roll.ambientMaeDegMax, curiousRollMae <= config.thresholds.roll.ambientMaeDegMax);
const refCuriousEyes = normalizedEyes(curious.reference), fabCuriousEyes = normalizedEyes(curious.fabushi);
const leftEyeMae = mae(refCuriousEyes.left, fabCuriousEyes.left), rightEyeMae = mae(refCuriousEyes.right, fabCuriousEyes.right);
check('curious.leftEye.normalizedMae', leftEyeMae, config.thresholds.eyes.normalizedMaeMax, leftEyeMae <= config.thresholds.eyes.normalizedMaeMax);
check('curious.rightEye.normalizedMae', rightEyeMae, config.thresholds.eyes.normalizedMaeMax, rightEyeMae <= config.thresholds.eyes.normalizedMaeMax);

const nodAt = Number(config.scenarios.find((x) => x.id === 'curious-nod').referenceOverrides.nodAtMs);
const refNod = firstPeak(curious.reference, 'roll', nodAt, 650), fabNod = firstPeak(curious.fabushi, 'roll', nodAt, 650);
if (refNod && fabNod) {
  const peakError = relativeError(refNod.score, fabNod.score);
  check('nod.rollPeak.relativeError', peakError, config.thresholds.roll.actionPeakRelativeErrorMax, peakError <= config.thresholds.roll.actionPeakRelativeErrorMax, { reference: refNod.score, fabushi: fabNod.score });
}

const hop = traces['curious-hop'];
const hopAt = Number(config.scenarios.find((x) => x.id === 'curious-hop').referenceOverrides.hopAtMs);
const refHop = firstPeak(hop.reference, 'bodyY', hopAt), fabHop = firstPeak(hop.fabushi, 'bodyY', hopAt);
if (refHop && fabHop) {
  const ampError = relativeError(refHop.score, fabHop.score), timeError = Math.abs(refHop.timeMs - fabHop.timeMs);
  check('hop.bodyY.peak.relativeError', ampError, config.thresholds.bodyY.peakRelativeErrorMax, ampError <= config.thresholds.bodyY.peakRelativeErrorMax, { reference: refHop.score, fabushi: fabHop.score });
  check('hop.bodyY.peakTime.absMs', timeError, config.thresholds.bounce.firstPeakTimeAbsMsMax, timeError <= config.thresholds.bounce.firstPeakTimeAbsMsMax);
}
const refHopSettle = settling(hop.reference, 'bodyY', hopAt), fabHopSettle = settling(hop.fabushi, 'bodyY', hopAt);
if (refHopSettle != null && fabHopSettle != null) {
  const delta = Math.abs(refHopSettle - fabHopSettle), limit = Math.max(config.thresholds.bodyY.settlingAbsMsMax, refHopSettle * config.thresholds.bodyY.settlingRelativeErrorMax);
  check('hop.bodyY.settling.absMs', delta, limit, delta <= limit, { referenceMs: refHopSettle, fabushiMs: fabHopSettle });
}

const wink = traces.wink;
const refWinkEyes = normalizedEyes(wink.reference), fabWinkEyes = normalizedEyes(wink.fabushi);
const refAsym = Math.max(...refWinkEyes.left.map((v, i) => Math.abs(v - refWinkEyes.right[i])));
const fabAsym = Math.max(...fabWinkEyes.left.map((v, i) => Math.abs(v - fabWinkEyes.right[i])));
const winkError = Math.abs(refAsym - fabAsym);
check('wink.asymmetry.absError', winkError, config.thresholds.eyes.winkAsymmetryErrorMax, winkError <= config.thresholds.eyes.winkAsymmetryErrorMax, { reference: refAsym, fabushi: fabAsym });

const blink = traces['blink-cadence'];
const refBlinks = blinkEvents(blink.reference), fabBlinks = blinkEvents(blink.fabushi);
const blinkCountDelta = Math.abs(refBlinks.length - fabBlinks.length);
check('blink.eventCountDelta', blinkCountDelta, config.thresholds.blink.eventCountDeltaMax, blinkCountDelta <= config.thresholds.blink.eventCountDeltaMax, { reference: refBlinks.length, fabushi: fabBlinks.length });
const refIntervals = refBlinks.slice(1).map((e, i) => e.at - refBlinks[i].at), fabIntervals = fabBlinks.slice(1).map((e, i) => e.at - fabBlinks[i].at);
if (refIntervals.length && fabIntervals.length) {
  const intervalError = relativeError(median(refIntervals), median(fabIntervals));
  check('blink.medianInterval.relativeError', intervalError, config.thresholds.blink.medianIntervalRelativeErrorMax, intervalError <= config.thresholds.blink.medianIntervalRelativeErrorMax, { referenceMs: median(refIntervals), fabushiMs: median(fabIntervals) });
}
if (refBlinks.length && fabBlinks.length) {
  const durationError = Math.abs(median(refBlinks.map((e) => e.durationMs)) - median(fabBlinks.map((e) => e.durationMs)));
  check('blink.closureDuration.absMs', durationError, config.thresholds.blink.closureDurationAbsMsMax, durationError <= config.thresholds.blink.closureDurationAbsMsMax);
}

const pointer = traces['pointer-gaze'];
for (const field of ['gazeX', 'gazeY']) {
  const refPeak = Math.max(...pointer.reference.map((x) => Math.abs(Number(x[field]))));
  const fabPeak = Math.max(...pointer.fabushi.map((x) => Math.abs(Number(x[field]))));
  const error = relativeError(refPeak, fabPeak);
  check('pointer.' + field + '.peak.relativeError', error, config.thresholds.gaze.peakRelativeErrorMax, error <= config.thresholds.gaze.peakRelativeErrorMax, { reference: refPeak, fabushi: fabPeak });
  const refSettle = settling(pointer.reference, field, 2200), fabSettle = settling(pointer.fabushi, field, 2200);
  if (refSettle != null && fabSettle != null) {
    const delta = Math.abs(refSettle - fabSettle);
    check('pointer.' + field + '.settling.absMs', delta, config.thresholds.gaze.settlingAbsMsMax, delta <= config.thresholds.gaze.settlingAbsMsMax, { referenceMs: refSettle, fabushiMs: fabSettle });
  }
}

const spin = traces.spin, spinAt = 350;
const refSpin = Math.max(...spin.reference.filter((x) => x.t >= spinAt).map((x) => Math.abs(Number(x.spin))));
const fabSpin = Math.max(...spin.fabushi.filter((x) => x.t >= spinAt).map((x) => Math.abs(Number(x.spin))));
const spinError = relativeError(refSpin, fabSpin);
check('spin.rotationPeak.relativeError', spinError, config.thresholds.spin.rotationPeakRelativeErrorMax, spinError <= config.thresholds.spin.rotationPeakRelativeErrorMax, { referenceDeg: refSpin, fabushiDeg: fabSpin });
const refSpinSettle = settling(spin.reference, 'spin', spinAt, 0.05), fabSpinSettle = settling(spin.fabushi, 'spin', spinAt, 0.05);
if (refSpinSettle != null && fabSpinSettle != null) {
  const delta = Math.abs(refSpinSettle - fabSpinSettle), limit = Math.max(config.thresholds.spin.settlingAbsMsMax, refSpinSettle * config.thresholds.spin.settlingRelativeErrorMax);
  check('spin.settling.absMs', delta, limit, delta <= limit, { referenceMs: refSpinSettle, fabushiMs: fabSpinSettle });
}

const bounce = traces.bounce, bounceAt = 350;
const refBounce = firstPeak(bounce.reference, 'bodyY', bounceAt), fabBounce = firstPeak(bounce.fabushi, 'bodyY', bounceAt);
if (refBounce && fabBounce) {
  const timeError = Math.abs(refBounce.timeMs - fabBounce.timeMs), ampError = relativeError(refBounce.score, fabBounce.score);
  check('bounce.firstPeak.time.absMs', timeError, config.thresholds.bounce.firstPeakTimeAbsMsMax, timeError <= config.thresholds.bounce.firstPeakTimeAbsMsMax, { referenceMs: refBounce.timeMs, fabushiMs: fabBounce.timeMs });
  check('bounce.firstPeak.amplitude.relativeError', ampError, config.thresholds.bounce.firstPeakRelativeErrorMax, ampError <= config.thresholds.bounce.firstPeakRelativeErrorMax, { reference: refBounce.score, fabushi: fabBounce.score });
}
const refRebound = reboundPeriod(bounce.reference, 'bodyY', bounceAt), fabRebound = reboundPeriod(bounce.fabushi, 'bodyY', bounceAt);
if (refRebound != null && fabRebound != null) {
  const error = relativeError(refRebound, fabRebound);
  check('bounce.reboundPeriod.relativeError', error, config.thresholds.bounce.periodRelativeErrorMax, error <= config.thresholds.bounce.periodRelativeErrorMax, { referenceMs: refRebound, fabushiMs: fabRebound });
} else check('bounce.reboundPeriod.detected', 1, 0, false, { referenceMs: refRebound, fabushiMs: fabRebound });
const refBounceSettle = settling(bounce.reference, 'bodyY', bounceAt), fabBounceSettle = settling(bounce.fabushi, 'bodyY', bounceAt);
if (refBounceSettle != null && fabBounceSettle != null) {
  const delta = Math.abs(refBounceSettle - fabBounceSettle);
  check('bounce.settling.absMs', delta, config.thresholds.bounce.settlingAbsMsMax, delta <= config.thresholds.bounce.settlingAbsMsMax, { referenceMs: refBounceSettle, fabushiMs: fabBounceSettle });
}
const preBounceSquashRef = mean(bounce.reference.filter((x) => x.t < bounceAt).slice(-6).map((x) => x.squash));
const preBounceSquashFab = mean(bounce.fabushi.filter((x) => x.t < bounceAt).slice(-6).map((x) => x.squash));
const refSquashPeak = Math.max(...bounce.reference.filter((x) => x.t >= bounceAt && x.t <= bounceAt + 900).map((x) => Math.abs(Number(x.squash) - preBounceSquashRef)));
const fabSquashPeak = Math.max(...bounce.fabushi.filter((x) => x.t >= bounceAt && x.t <= bounceAt + 900).map((x) => Math.abs(Number(x.squash) - preBounceSquashFab)));
const squashPeakError = Math.abs(refSquashPeak - fabSquashPeak);
check('bounce.squash.peakAbsError', squashPeakError, config.thresholds.squash.peakAbsErrorMax, squashPeakError <= config.thresholds.squash.peakAbsErrorMax, { reference: refSquashPeak, fabushi: fabSquashPeak });

for (const id of ['spin', 'bounce', 'burst']) {
  const data = traces[id];
  const correlation = pearson(data.referenceEnergy, data.fabushiEnergy);
  check(id + '.visualMotion.energyCorrelation', correlation, config.thresholds.visualMotion.temporalDifferenceCorrelationMin, correlation >= config.thresholds.visualMotion.temporalDifferenceCorrelationMin);
  if (id === 'burst') {
    const refShape = energyShape(data.referenceEnergy, data.frameIntervalMs), fabShape = energyShape(data.fabushiEnergy, data.frameIntervalMs);
    const peakDelta = Math.abs(Number(refShape.peakMs) - Number(fabShape.peakMs));
    const durationError = relativeError(refShape.durationMs, fabShape.durationMs);
    check('burst.motionEnvelope.peakTime.absMs', peakDelta, config.thresholds.burst.peakTimeAbsMsMax, peakDelta <= config.thresholds.burst.peakTimeAbsMsMax, { referenceMs: refShape.peakMs, fabushiMs: fabShape.peakMs });
    check('burst.motionEnvelope.duration.relativeError', durationError, config.thresholds.burst.durationRelativeErrorMax, durationError <= config.thresholds.burst.durationRelativeErrorMax, { referenceMs: refShape.durationMs, fabushiMs: fabShape.durationMs });
  }
}

const transitions = traces['state-transition'];
const transitionScenario = config.scenarios.find((x) => x.id === 'state-transition');
for (const event of transitionScenario.events.filter((x) => x.type === 'state')) {
  const refSettle = settling(transitions.reference, 'roll', Number(event.atMs), 0.15), fabSettle = settling(transitions.fabushi, 'roll', Number(event.atMs), 0.15);
  if (refSettle != null && fabSettle != null) {
    const delta = Math.abs(refSettle - fabSettle);
    check('transition.' + event.state + '.rollSettling.absMs', delta, config.thresholds.stateTransition.settlingAbsMsMax, delta <= config.thresholds.stateTransition.settlingAbsMsMax, { referenceMs: refSettle, fabushiMs: fabSettle });
  }
}
const refTransitionEyes = normalizedEyes(transitions.reference), fabTransitionEyes = normalizedEyes(transitions.fabushi);
const finalStart = transitions.reference.findIndex((x) => x.t >= 5200);
for (const field of ['bodyY', 'roll', 'squash', 'gazeX', 'gazeY']) {
  const ref = transitions.reference.slice(finalStart).map((x) => Number(x[field])), fab = transitions.fabushi.slice(finalStart).map((x) => Number(x[field]));
  const scale = Math.max(1, ...ref.map((x) => Math.abs(x))), error = mae(ref, fab) / scale;
  check('transition.final.' + field + '.normalizedError', error, config.thresholds.stateTransition.endStateNormalizedErrorMax, error <= config.thresholds.stateTransition.endStateNormalizedErrorMax);
}
const leftFinal = mae(refTransitionEyes.left.slice(finalStart), fabTransitionEyes.left.slice(finalStart));
const rightFinal = mae(refTransitionEyes.right.slice(finalStart), fabTransitionEyes.right.slice(finalStart));
check('transition.final.leftEye.normalizedError', leftFinal, config.thresholds.stateTransition.endStateNormalizedErrorMax, leftFinal <= config.thresholds.stateTransition.endStateNormalizedErrorMax);
check('transition.final.rightEye.normalizedError', rightFinal, config.thresholds.stateTransition.endStateNormalizedErrorMax, rightFinal <= config.thresholds.stateTransition.endStateNormalizedErrorMax);

const failures = checks.filter((x) => !x.pass);
const report = {
  schema: 'fabushi.avatar.motion-parity.report.v1',
  generatedAt: new Date().toISOString(),
  sourceSha: raw.sourceSha,
  referenceSha: raw.referenceSha,
  thresholds: config.thresholds,
  checks,
  failureCount: failures.length,
  pass: failures.length === 0,
};
await writeFile(path.join(evidenceRoot, 'motion-parity-report.json'), JSON.stringify(report, null, 2) + '\n');
const csv = ['check,value,limit,pass'].concat(checks.map((x) => [JSON.stringify(x.name), Number.isFinite(Number(x.value)) ? Number(x.value) : '', Number.isFinite(Number(x.limit)) ? Number(x.limit) : '', x.pass ? 'PASS' : 'FAIL'].join(','))).join('\n') + '\n';
await writeFile(path.join(evidenceRoot, 'motion-parity-checks.csv'), csv);
console.log(JSON.stringify({ pass: report.pass, failureCount: report.failureCount, failures }, null, 2));
if (!report.pass) process.exitCode = 1;
