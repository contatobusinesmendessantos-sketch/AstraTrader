# ASTRA LINK v1.0 — Communication Contract

ASTRA LINK is the versioned local communication contract between ASTRA SENTINEL and ASTRA TRADER.

## Authority model

- ASTRA SENTINEL observes market data, calculates indicators, evaluates its strategy and publishes a signal/intention.
- ASTRA TRADER is the execution authority and applies authorization, risk, exposure and position gates.
- ASTRA SENTINEL does not place market orders in v1.0.

## Outbound

`AstraLink\\sentinel_to_astra.csv`

The SIGNAL envelope carries protocol version, message type, strategy/source/target, CycleID, timestamp, symbol, timeframe, signal, candle/indicator data and reason.

## Inbound

`AstraLink\\astra_to_sentinel.csv`

The AUTH_RESPONSE envelope has exactly nine fields: protocol version, message type, CycleID, timestamp, status, reason, approved volume, stop-loss points and take-profit points.

Valid statuses are `APPROVED`, `BLOCKED`, `EXECUTED` and `ERROR`. Invalid field counts, protocol versions, timestamps, statuses and numeric risk fields are rejected.

## Pending lifecycle

Signals requiring authorization enter one in-memory pending state. The Sentinel polls for an AUTH_RESPONSE and rejects malformed, stale, duplicate, unsolicited or mismatched CycleIDs. The default authorization timeout is 5 seconds. Pending state is not persisted across EA restarts.

## Transport

Production uses `FILE_COMMON`. A non-empty test namespace uses the current terminal's `MQL5\\Files` sandbox. Writes use a temporary file and promotion to the target path to keep the published snapshot deterministic.

## Diagnostic mode

Diagnostic mode is isolated to namespaces beginning `ASTRA_SENTINEL_TEST_` and emits a synthetic signal without order execution. The test responder is a harness and must not be used as the production authorization authority.
