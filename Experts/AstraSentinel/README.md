# ASTRA SENTINEL v1.0

ASTRA SENTINEL is a Mini Index specialist that generates strategy signals and delegates authorization/execution to ASTRA TRADER through ASTRA LINK.

## Authority

- SENTINEL observes market data, calculates indicators, evaluates its strategy and publishes signal/intention.
- ASTRA TRADER is the execution authority and applies authorization, risk, exposure and position gates.
- SENTINEL does not place market orders in v1.0.

## Runtime transport

Production uses the local `FILE_COMMON` transport through the `AstraLink` paths. A configured test namespace routes the files to the current terminal's `MQL5\\Files` sandbox.

## Main artifacts

- `AstraSentinel.mq5` — EA lifecycle, strategy evaluation, signal publication, pending authorization state and telemetry.
- `Core/` — protocol configuration and shared data structures.
- `Indicators/` — market indicator calculations.
- `Link/` — versioned message protocol and file transport.
- `Storage/` — local telemetry persistence.
- `Strategy/` — signal-generation rules.
- `Tools/` — deterministic protocol/runtime test harnesses.

## Safety

The test responder is a local harness only. It must not be used as the production authorization authority.
