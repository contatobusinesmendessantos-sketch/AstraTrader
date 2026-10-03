# Build / Validation Notes

1. Compile `AstraSentinel.mq5`.
2. Confirm zero errors and zero warnings.
3. Attach it to the intended Mini Index symbol.
4. Use M1 data and enough history for all windows.
5. For production use, confirm `AstraLink\\sentinel_to_astra.csv` appears in the common files area.
6. Confirm `AstraLink\\sentinel_heartbeat.csv` updates.
7. Use `Tools/AstraLinkTestResponder.mq5` only for local handshake testing.
8. Verify CycleID continuity and matching AUTH_RESPONSE cycle ids.
9. Compare indicator values with an independent reference before treating the L&S threshold 25 as validated.
10. Only after the contract and telemetry are stable should ASTRA TRADER consume the live signal path.

## Isolated ASTRA LINK diagnostic

1. Compile `AstraSentinel.mq5`, `Tools/AstraLinkTestResponder.mq5`, and `Tools/AstraLinkProtocolTest.mq5`.
2. Set the same `InpLinkNamespace` (beginning with `ASTRA_SENTINEL_TEST_`) in both EAs. A non-empty namespace uses the current terminal's `MQL5\\Files` sandbox, not `FILE_COMMON`; attach both EAs only in the same terminal profile.
3. Confirm the namespace's local `MQL5\\Files` directory contains no old request or response files; use a fresh namespace rather than overwriting evidence from another run.
4. Run `Tools/AstraLinkProtocolTest.mq5` before attaching either EA. It checks serialization, sandbox file roundtrip, deserialization, unsupported versions, missing fields, and trailing-NUL rejection without trading.
5. Set `InpDiagnosticMode=true` only after the namespace is confirmed. Optionally enable `InpLinkDebug` to record parser stage, field, and error without dumping the raw payload.
6. Attach `AstraLinkTestResponder.mq5` separately. Its default response is BLOCKED; use its delay, CycleID offset, protocol-version override, and duplicate-response inputs to exercise timeout, late-response, mismatch, malformed-response, and duplicate handling.
7. Reconstruct each cycle from `<namespace>\\sentinel_link_runtime.csv` and `<namespace>\\sentinel_telemetry.csv` in the terminal's local `MQL5\\Files` sandbox. Verify runtime, market, and message/server timestamps are not conflated.
8. Disable diagnostic mode and remove only the named test namespace files before returning to normal observation. Diagnostic mode sends a synthetic signal but contains no order execution.
9. Pending state is in-memory only and is not recovered after an EA restart; verify restart behavior as idle/unsolicited-response rejection.
