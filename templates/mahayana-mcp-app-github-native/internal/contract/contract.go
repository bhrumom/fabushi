package contract

import (
    "encoding/json"
    "errors"
    "fmt"
    "sort"
    "sync"
)

var (
    PluginID = "io.mahayana.example.github-native-app"
    Version = "0.1.0"
)

type Request struct {
    JSONRPC string          `json:"jsonrpc"`
    ID      json.RawMessage `json:"id,omitempty"`
    Method  string          `json:"method"`
    Params  json.RawMessage `json:"params,omitempty"`
}

type Response struct {
    JSONRPC string          `json:"jsonrpc"`
    ID      json.RawMessage `json:"id,omitempty"`
    Result  any             `json:"result,omitempty"`
    Error   *RPCError       `json:"error,omitempty"`
}

type RPCError struct {
    Code    int    `json:"code"`
    Message string `json:"message"`
}

type Task struct {
    ID     string `json:"id"`
    Text   string `json:"text"`
    Status string `json:"status"`
}

type Runtime struct {
    mu    sync.Mutex
    next  int
    tasks map[string]Task
    logs  []string
}

func NewRuntime() *Runtime {
    return &Runtime{tasks: map[string]Task{}}
}

func ToolNames() []string {
    return []string{"cancel", "logs", "send", "status"}
}

func (r *Runtime) Call(name string, arguments map[string]any) (map[string]any, error) {
    r.mu.Lock()
    defer r.mu.Unlock()
    switch name {
    case "send":
        text, _ := arguments["text"].(string)
        if text == "" {
            return nil, errors.New("invalid_input")
        }
        r.next++
        id := fmt.Sprintf("task-%d", r.next)
        task := Task{ID: id, Text: text, Status: "queued"}
        r.tasks[id] = task
        r.logs = append(r.logs, "queued "+id)
        return result("Queued "+id, map[string]any{"task": task}), nil
    case "status":
        id, _ := arguments["taskId"].(string)
        task, ok := r.tasks[id]
        if !ok {
            return nil, errors.New("task_not_found")
        }
        return result("Status for "+id, map[string]any{"task": task}), nil
    case "cancel":
        id, _ := arguments["taskId"].(string)
        task, ok := r.tasks[id]
        if !ok {
            return nil, errors.New("task_not_found")
        }
        task.Status = "cancelled"
        r.tasks[id] = task
        r.logs = append(r.logs, "cancelled "+id)
        return result("Cancelled "+id, map[string]any{"task": task}), nil
    case "logs":
        logs := append([]string(nil), r.logs...)
        return result("Runtime logs", map[string]any{"logs": logs}), nil
    default:
        return nil, errors.New("tool_not_found")
    }
}

func result(text string, structured map[string]any) map[string]any {
    return map[string]any{
        "content": []map[string]string{{"type": "text", "text": text}},
        "structuredContent": structured,
    }
}

func (r *Runtime) Handle(req Request) Response {
    response := Response{JSONRPC: "2.0", ID: req.ID}
    switch req.Method {
    case "initialize":
        response.Result = map[string]any{
            "protocolVersion": "2025-11-25",
            "capabilities": map[string]any{"tools": map[string]any{}, "resources": map[string]any{}},
            "serverInfo": map[string]string{"name": PluginID, "version": Version},
        }
    case "tools/list":
        names := ToolNames()
        sort.Strings(names)
        tools := make([]map[string]any, 0, len(names))
        for _, name := range names {
            tools = append(tools, map[string]any{
                "name": name,
                "description": "Mahayana reference tool: " + name,
                "inputSchema": map[string]any{"type": "object", "additionalProperties": true},
                "_meta": map[string]any{"ui": map[string]any{"resourceUri": "ui://" + PluginID + "/main"}},
            })
        }
        response.Result = map[string]any{"tools": tools}
    case "tools/call":
        var params struct {
            Name      string         `json:"name"`
            Arguments map[string]any `json:"arguments"`
        }
        if err := json.Unmarshal(req.Params, &params); err != nil {
            response.Error = &RPCError{Code: -32602, Message: "invalid_input"}
            return response
        }
        value, err := r.Call(params.Name, params.Arguments)
        if err != nil {
            response.Error = &RPCError{Code: -32000, Message: err.Error()}
        } else {
            response.Result = value
        }
    case "resources/list":
        response.Result = map[string]any{"resources": []map[string]any{{
            "uri": "ui://" + PluginID + "/main",
            "name": "Mahayana GitHub-native App",
            "mimeType": "text/html;profile=mcp-app",
        }}}
    default:
        response.Error = &RPCError{Code: -32601, Message: "method_not_found"}
    }
    return response
}
