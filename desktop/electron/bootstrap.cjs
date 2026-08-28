'use strict';

// Keep electron/main.cjs as the canonical desktop runtime. Bootstrap composes
// trusted-main capability wrappers only; no wrapper owns a second agent loop.
const nativeCapabilities = require('./native-capability-handlers.cjs');
const { wrapNativeCapabilityHandlers } = require('./credential-gateway.cjs');
const { wrapNativeCapabilityHandlers: wrapDesignArtifactHandlers } = require('./design-artifact-runtime.cjs');

nativeCapabilities.createNativeCapabilityHandlers = wrapDesignArtifactHandlers(
  wrapNativeCapabilityHandlers(nativeCapabilities.createNativeCapabilityHandlers),
);

require('./main.cjs');
