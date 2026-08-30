# Diagnostics Logging

Tilt Arena uses [`apple/swift-log`](https://github.com/apple/swift-log) as the
only call-site logging API. `AppDiagnostics.bootstrap()` installs a
`MultiplexLogHandler` once at launch. Debug-and-higher events go to Apple's
unified log, while info-and-higher events also go to the app-owned JSONL log:

- Apple's [unified logging system](https://developer.apple.com/documentation/os/logging)
  (`OSLog`) for Console and Xcode inspection.
- App-owned, line-delimited JSON files for deterministic in-app viewing and
  sharing.

Apple's [MetricKit](https://developer.apple.com/documentation/metrickit) is also
subscribed at launch. The newest retention-sized cohort of past diagnostic
payloads is imported on a utility queue, one payload at a time under the store's
aggregate byte budget. Future crash, hang, CPU-exception, disk-write, and
app-launch payloads follow the same bounded path and are content-deduplicated
for the next user-created report. MetricKit delivery is retrospective; it
complements event breadcrumbs and does not replace symbolicated App Store or
Xcode crash reports.

## Event Contract

Create a category logger once and emit stable dot-separated event names:

```swift
private let logger = AppDiagnostics.logger(.run)

logger.notice("run.started", metadata: [
    "mode": "classic"
])

logger.error("profile.save_failed", error: error)
```

Use `debug` for high-volume local investigation, `info` for routine state
changes, `notice` for user-visible milestones, `warning` for recoverable
abnormal states, and `error`/`critical` for failures and broken invariants.

Do not log per-frame movement or raw motion samples. Metadata must remain small,
scalar, and bounded. Never add tokens, email addresses, player or device names,
vendor identifiers, or other user identifiers. The persistence handler also
bounds messages, metadata count/depth/length, redacts sensitive-looking keys,
and records Swift errors only as type plus `NSError` domain/code; arbitrary
localized error descriptions are not persisted.

## Storage and Failure Isolation

JSONL writes run on a bounded utility queue, never on the SpriteKit update path.
When the queue is full, diagnostics are dropped instead of creating unbounded
work. Queue drops and write failures are counted and coalesced into one
`diagnostics.persistence_degraded` record after storage recovers. These health
counters are included in exported reports.

Production retention is bounded as follows:

- JSONL: 512 KiB current file, five archives, 3 MiB total, 256 pending writes.
- MetricKit: eight payload files, 8 MiB total.
- Generated text reports: three files, 32 MiB total.

Diagnostics directories and files are excluded from backup and use iOS file
protection. Routine JSONL persistence is best-effort. MetricKit persistence
refuses a new payload if it cannot first prove that the count and byte quotas
will remain satisfied. Any persistence, rotation, or cleanup failure remains
isolated from gameplay.

## View and Share in the App

Open **Options**, then select **VIEW / SHARE LOGS**. Tilt Arena builds one
immutable `.txt` report off the main actor and opens it with Apple's
`QLPreviewController`. The Share button presents the system
`UIActivityViewController`, including the correct popover anchor on iPad-class
presentations. The temporary report is removed when the preview closes.

The report contains the newest bounded log tails, without first copying whole
log files, plus:

- app/OS/session metadata and a bounded gameplay snapshot;
- diagnostics persistence health;
- chronological JSONL event records;
- malformed/unreadable record counts; and
- raw stored MetricKit diagnostic payloads.

Treat a shared report as technical support data: inspect the preview before
sending it to another person or service.

## Local Inspection

For the booted simulator:

```sh
scripts/tilt-logs tail
scripts/tilt-logs list
scripts/tilt-logs copy /tmp/tilt-logs
```

The underlying files remain ordinary JSONL:

```sh
scripts/tilt-logs cat | jq 'select(.category == "run")'
scripts/tilt-logs cat | rg '"message":"run.finished"'
```

Physical-device retrieval can use Apple's `devicectl` to copy
`Library/Application Support/Diagnostics` from the app container. Keep each
release archive and its dSYMs so MetricKit and crash-report call stacks can be
symbolicated, as required by Apple's
[crash-report workflow](https://developer.apple.com/documentation/xcode/diagnosing-issues-using-crash-reports-and-device-logs).

## Dependency Choice

SwiftLog already supplies the logging facade and multiplexing needed by the
app. Apple's `OSLog`, MetricKit, Quick Look, and system share sheet cover the
platform-specific pieces. A small app-owned JSONL handler remains necessary for
the stable schema, privacy bounds, rotation policy, and shareable offline
report; adding CocoaLumberjack or another logging stack would duplicate the
existing facade without removing that app-specific work.
