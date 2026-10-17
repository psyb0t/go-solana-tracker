# Changelog

All notable changes per release. Versions follow [semver](https://semver.org).

## v0.1.0, 2026-10-17

- Added `solanatracker`, a REST client generated with oapi-codegen from the Solana Tracker Data API specification, version 1.0.0, OpenAPI 3.1, from https://docs.solanatracker.io/data-api/openapi.json. It covers all 51 paths and 52 operations for token search, prices, holders, trades, charts, wallet data, profit and loss, statistics, credits and subscriptions.
- Added `ws`, package `solanatrackerws`, generated with gen-asyncapi from the Datastream WebSocket specification, version 5.0.0, AsyncAPI 3.0, from https://docs.solanatracker.io/datastream/asyncapi.json. It covers all 43 channels for room subscriptions and streaming market, wallet and Jupiter DCA events.
- Number fields are `float64`. Spec patches preserve nullable fields and mixed cursor types, and normalize server-oriented inline WebSocket messages for client generation and room matching.
- Added offline REST and WebSocket decoding tests, development tooling and the `go-solana-tracker` agent skill. `make generate` downloads both source specs into the gitignored `api/` directory; neither spec is redistributed.
