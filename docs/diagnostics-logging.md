# Diagnostics Logging

Tilt Arena uses `apple/swift-log` as the app logging API and writes exportable
diagnostics to bounded JSONL files in the app container.

## Backend Choice

`apple/swift-log` provides the logging API and `MultiplexLogHandler`, but it does
not include JSONL file persistence or rotation.

`crspybits/swift-log-file` was evaluated as a lightweight existing file backend.
It is iOS-compatible, but it only covers simple file logging and does not provide
the JSONL schema, bounded rotation policy, export metadata, or CLI-oriented
diagnostics bundle required for this app.

`CocoaLumberjack` provides mature rolling file logs, but it is a much larger
dependency than the current need. The first-party JSONL handler keeps the
surface area small and makes the on-disk format stable for support tooling.

## Local Inspection

For the booted simulator:

```sh
scripts/tilt-logs tail
scripts/tilt-logs list
scripts/tilt-logs copy /tmp/tilt-logs
```

The underlying log files are plain line-delimited JSON:

```sh
scripts/tilt-logs cat | jq 'select(.category == "run")'
scripts/tilt-logs cat | rg '"message":"run.finished"'
```

Physical device retrieval should use Apple `devicectl` or an open-source tool
such as `idb` to pull `Library/Application Support/Diagnostics/Logs` from the
app container.
