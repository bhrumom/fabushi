//go:build js && wasm

package main

import (
    "encoding/json"
    "syscall/js"

    "github.com/example/mahayana-github-native-app/internal/contract"
)

func main() {
    runtime := contract.NewRuntime()
    handler := js.FuncOf(func(_ js.Value, args []js.Value) any {
        if len(args) != 1 {
            return `{"jsonrpc":"2.0","error":{"code":-32602,"message":"invalid_input"}}`
        }
        var request contract.Request
        if err := json.Unmarshal([]byte(args[0].String()), &request); err != nil {
            return `{"jsonrpc":"2.0","error":{"code":-32700,"message":"parse_error"}}`
        }
        encoded, _ := json.Marshal(runtime.Handle(request))
        return string(encoded)
    })
    js.Global().Set("mahayanaMcpCall", handler)
    select {}
}
