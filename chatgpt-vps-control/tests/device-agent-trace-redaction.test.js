import assert from "node:assert/strict";
import test from "node:test";
import { redactDeviceCallArguments, redactDeviceCallResult } from "../lib/device-agent.js";

test("device trace redacts App MCP and native semantic typed values while retaining routing metadata", () => {
  const app = redactDeviceCallArguments("fabushi.app.action", {
    generation: 4,
    agentId: "login.username",
    action: "setValue",
    value: "private user text",
  });
  assert.equal(app.generation, 4);
  assert.equal(app.agentId, "login.username");
  assert.equal(app.value, "<redacted-input>");

  const native = redactDeviceCallArguments("computer_use_bridge", {
    operation: "type_text",
    application: "Notes",
    text: "private note",
  });
  assert.equal(native.operation, "type_text");
  assert.equal(native.application, "Notes");
  assert.equal(native.text, "<redacted-input>");

  assert.equal(redactDeviceCallArguments("secure_input_submit", { envelope: "ciphertext" }), "<secure-input-redacted>");
});


test("device trace redacts App MCP semantic result labels while preserving stable control state", () => {
  const result = redactDeviceCallResult("fabushi.app.snapshot", {
    route: "/messages",
    screen: "messenger",
    generation: 11,
    elements: [{
      agentId: "test:conversation-row",
      role: "button",
      name: "Private conversation title",
      text: "Private message content",
      description: "Private description",
      visible: true,
      enabled: true,
    }],
  });
  assert.equal(result.route, "/messages");
  assert.equal(result.screen, "messenger");
  assert.equal(result.generation, 11);
  assert.equal(result.elements[0].agentId, "test:conversation-row");
  assert.equal(result.elements[0].role, "button");
  assert.equal(result.elements[0].name, "<redacted-ui-text>");
  assert.equal(result.elements[0].text, "<redacted-ui-text>");
  assert.equal(result.elements[0].description, "<redacted-ui-text>");
  assert.equal(result.elements[0].visible, true);
});
