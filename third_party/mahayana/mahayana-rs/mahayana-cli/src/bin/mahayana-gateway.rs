use mahayana_gateway::{GatewayDispatcher, event_notification};
use mahayana_gateway_runtime::NativeRuntimeGateway;
use std::io::{self, BufRead, Write};
use std::sync::mpsc::{self, TryRecvError};
use std::thread;

fn main() {
    if let Err(error) = run() {
        eprintln!("mahayana-gateway: {error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let handler = NativeRuntimeGateway::create().map_err(|error| error.message)?;
    let mut dispatcher = GatewayDispatcher::new(handler);
    let (sender, receiver) = mpsc::channel::<String>();

    thread::spawn(move || {
        let stdin = io::stdin();
        for line in stdin.lock().lines() {
            let Ok(line) = line else { break };
            if sender.send(line).is_err() {
                break;
            }
        }
    });

    let stdout = io::stdout();
    let mut output = stdout.lock();
    let mut stdin_closed = false;

    loop {
        loop {
            match receiver.try_recv() {
                Ok(line) => {
                    if line.trim().is_empty() {
                        continue;
                    }
                    let dispatched = dispatcher.dispatch_json(&line);
                    if let Some(response) = dispatched.response {
                        serde_json::to_writer(&mut output, &response)
                            .map_err(|error| error.to_string())?;
                        output.write_all(b"\n").map_err(|error| error.to_string())?;
                    }
                    for event in dispatched.events {
                        output
                            .write_all(
                                event_notification(&event)
                                    .map_err(|error| error.to_string())?
                                    .as_bytes(),
                            )
                            .map_err(|error| error.to_string())?;
                        output.write_all(b"\n").map_err(|error| error.to_string())?;
                    }
                    output.flush().map_err(|error| error.to_string())?;
                }
                Err(TryRecvError::Empty) => break,
                Err(TryRecvError::Disconnected) => {
                    stdin_closed = true;
                    break;
                }
            }
        }

        if let Some(event) = dispatcher
            .handler_mut()
            .receive_turn_event(50)
            .map_err(|error| error.message)?
        {
            output
                .write_all(
                    event_notification(&event)
                        .map_err(|error| error.to_string())?
                        .as_bytes(),
                )
                .map_err(|error| error.to_string())?;
            output.write_all(b"\n").map_err(|error| error.to_string())?;
            output.flush().map_err(|error| error.to_string())?;
        } else if stdin_closed {
            break;
        }
    }

    Ok(())
}
