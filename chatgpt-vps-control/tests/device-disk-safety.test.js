import assert from "node:assert/strict";
import test from "node:test";
import {
  DEVICE_DISK_SAFETY_INSTRUCTIONS,
  ONE_GIB,
  enforceDiskPreflight,
  minimumDiskReserveBytes,
  normalizeDiskPreflight,
} from "../lib/device-disk-safety.js";

const GIB = 1024 ** 3;

function fakeStatfs({ totalBytes, availableBytes, blockSize = 4096 }) {
  return async () => ({
    bsize: blockSize,
    blocks: Math.floor(totalBytes / blockSize),
    bfree: Math.floor(availableBytes / blockSize),
    bavail: Math.floor(availableBytes / blockSize),
  });
}

test("disk safety instructions are exposed as a durable runtime policy", () => {
  assert.match(DEVICE_DISK_SAFETY_INSTRUCTIONS, /Before every device operation/i);
  assert.match(DEVICE_DISK_SAFETY_INSTRUCTIONS, /max\(1 GiB, 5%/i);
  assert.match(DEVICE_DISK_SAFETY_INSTRUCTIONS, /fail closed/i);
});

test("minimum reserve is max of one GiB and five percent", () => {
  assert.equal(minimumDiskReserveBytes(10 * GIB), ONE_GIB);
  assert.equal(minimumDiskReserveBytes(45 * GIB), Math.ceil(45 * GIB * 0.05));
});

test("writes are rejected when projected free space crosses the reserve", async () => {
  await assert.rejects(
    () => enforceDiskPreflight({
      impact: "writes",
      reason: "A staged archive and its extraction may coexist.",
      targets: [{ path: "/tmp/output", peakAdditionalBytes: 2 * GIB }],
    }, {
      cwd: "/",
      statfsFn: fakeStatfs({ totalBytes: 45 * GIB, availableBytes: 3 * GIB }),
    }),
    /Disk safety preflight rejected/,
  );
});

test("writes pass when peak use preserves the reserve", async () => {
  const result = await enforceDiskPreflight({
    impact: "writes",
    reason: "Bounded file write.",
    targets: [{ path: "/tmp/output", peakAdditionalBytes: 512 * 1024 }],
  }, {
    cwd: "/",
    statfsFn: fakeStatfs({ totalBytes: 45 * GIB, availableBytes: 4 * GIB }),
  });
  assert.equal(result.impact, "writes");
  assert.equal(result.checks.length, 1);
  assert.ok(result.checks[0].projectedRemainingBytes >= result.checks[0].requiredReserveBytes);
});

test("preflight fails closed when write targets are omitted or none carries targets", () => {
  assert.throws(
    () => normalizeDiskPreflight({ impact: "writes", reason: "Unknown write footprint.", targets: [] }),
    /must contain every affected filesystem/,
  );
  assert.throws(
    () => normalizeDiskPreflight({ impact: "none", reason: "Read only.", targets: [{ path: "/tmp", peakAdditionalBytes: 0 }] }),
    /must be empty/,
  );
});
