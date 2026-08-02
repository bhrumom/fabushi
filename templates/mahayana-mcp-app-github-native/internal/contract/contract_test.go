package contract

import (
    "encoding/json"
    "testing"
)

func TestToolContract(t *testing.T) {
    runtime := NewRuntime()
    sent, err := runtime.Call("send", map[string]any{"text": "hello"})
    if err != nil {
        t.Fatal(err)
    }
    structured := sent["structuredContent"].(map[string]any)
    task := structured["task"].(Task)
    if task.ID == "" || task.Status != "queued" {
        t.Fatalf("unexpected task: %#v", task)
    }
    status, err := runtime.Call("status", map[string]any{"taskId": task.ID})
    if err != nil || status["structuredContent"] == nil {
        t.Fatalf("status failed: %#v %v", status, err)
    }
    cancelled, err := runtime.Call("cancel", map[string]any{"taskId": task.ID})
    if err != nil || cancelled["structuredContent"] == nil {
        t.Fatalf("cancel failed: %#v %v", cancelled, err)
    }
}

func TestMCPResponseHasTextAndStructuredContent(t *testing.T) {
    runtime := NewRuntime()
    params, _ := json.Marshal(map[string]any{"name": "send", "arguments": map[string]any{"text": "hello"}})
    response := runtime.Handle(Request{JSONRPC: "2.0", ID: json.RawMessage("1"), Method: "tools/call", Params: params})
    result := response.Result.(map[string]any)
    if result["content"] == nil || result["structuredContent"] == nil {
        t.Fatalf("missing result representations: %#v", result)
    }
}
