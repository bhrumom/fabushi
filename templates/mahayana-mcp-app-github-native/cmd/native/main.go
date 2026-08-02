package main

import (
    "bufio"
    "encoding/json"
    "fmt"
    "os"

    "github.com/example/mahayana-github-native-app/internal/contract"
)

func main() {
    runtime := contract.NewRuntime()
    scanner := bufio.NewScanner(os.Stdin)
    encoder := json.NewEncoder(os.Stdout)
    for scanner.Scan() {
        var request contract.Request
        if err := json.Unmarshal(scanner.Bytes(), &request); err != nil {
            _ = encoder.Encode(contract.Response{JSONRPC: "2.0", Error: &contract.RPCError{Code: -32700, Message: "parse_error"}})
            continue
        }
        if err := encoder.Encode(runtime.Handle(request)); err != nil {
            fmt.Fprintln(os.Stderr, err)
            os.Exit(1)
        }
    }
    if err := scanner.Err(); err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}
