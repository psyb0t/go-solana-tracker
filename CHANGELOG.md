# Changelog

All notable changes per release. Versions follow [semver](https://semver.org).

## v0.4.0, 2026-11-18

- Changed `TradesResponse.NextCursor` from `*int` to `*string`. Code that reads the cursor as an integer must treat it as a string and pass it back unchanged as `cursor`.
- Added `Timezone` to `GetChartTokenParams` and `GetChartTokenPoolParams`. Hour and longer candles start at midnight in that time zone when it is set.
- Added a `503` response to `GetTradesTokenAddressResponse`, `GetTradesTokenAddressPoolAddressResponse`, `GetTradesTokenAddressByWalletOwnerResponse`, `GetTradesTokenAddressPoolAddressOwnerResponse` and `GetWalletOwnerTradesResponse`, with `JSON503`, `Headers503` and `GetJSON503`, plus the header types such as `GetTradesTokenAddressResponse503Headers`.
- Added `HandleMessage(ctx, MessagePayload) error` to `ws.Handler`. Custom implementations must add it; `UnimplementedHandler` ignores the message.
- Added the types `MessagePayload`, `JoinPayload`, `LeavePayload`, `MessageJoin`, `MessageLeave` and `MessageMessage` to `ws`.
- Added `Subscribe` and `Unsubscribe` methods on `ws.Client` for the V2 trade rooms: `KolTradesV2`, `PoolTradesV2`, `PoolWalletTradesV2`, `TokenTradesV2`, `WalletTradesV2` and `WhaleTradesV2`, with the address templates such as `TokenTradesV2AddressTemplate`.
- Added the V2 trade models `TradesV2Live`, `TradeV2`, `TradeV2Type`, `TradeLegV2`, `TradeTokenV2`, `TradePoolV2`, `TradeRouteV2`, `TradeFeesV2`, `TradeComputeV2` and `WalletIdentityV2`, with its identity constants.
- Raised the minimum Go version in `go.mod` from 1.26.10 to 1.26.11, which fixes the `net/http` vulnerability GO-2026-6859 found by govulncheck. The development image uses the matching base image.

## v0.3.0, 2026-11-01

- Removed the `Timezone` field from `GetChartTokenParams` and `GetChartTokenPoolParams`. `NewGetChartTokenRequest` and `NewGetChartTokenPoolRequest` no longer send the `timezone` query parameter. Callers that set `Timezone` must delete that line; the API no longer takes it in the regenerated spec.

## v0.2.0, 2026-10-31

- Added `GetAccountAddressTransfers` and `GetAccountAddressTransfersWithResponse` for account transfer history, with `GetAccountAddressTransfersParams` (filters for direction, status, type, DEX and sort order), `NewGetAccountAddressTransfersRequest` and `ParseGetAccountAddressTransfersResponse`.
- Added the response models `AccountTransfersResponse`, `AccountTransfer`, `TransferTransaction`, `TransferToken`, `TransferTokenTotal` and `TransferParty`, with enums and `Valid` methods for direction, status and type.
- Added the methods `GetAccountAddressTransfers` to `ClientInterface` and `GetAccountAddressTransfersWithResponse` to `ClientWithResponsesInterface`. Custom implementations of these interfaces must add them.
- Added `Currency` (`usd`, `eur`, `sol`) and `MarketCap` parameters to the four token trade endpoints, `Currency` to `TokenTradesResponse`, and `MarketCap` and `Price` to `TokenTrade`.
- Added search parameters `MinBundlerBalance`, `MaxBundlerBalance`, `MinMigrationSeconds`, `MaxMigrationSeconds`, `MinTokenCreatedAt`, `MaxTokenCreatedAt` and `QuoteToken` to `GetSearchParams`, the sort value `GetSearchParamsSortByMigrationSeconds`, and `MigrationSeconds` to `SearchToken`.
- Added chart intervals `30s`, `3h` and `5h` to the `GetChartTokenParams` and `GetChartTokenPoolParams` type enums.

## v0.1.3, 2026-10-28

- Updated Semgrep in the development image to 1.182.1 and refreshed its locked dependencies. certifi 2026.10.23 drops the emSign root CAs whose intermediate keys were compromised (GHSA-6q48-6c7w-9gw2).
- Dependabot no longer opens pull requests for `mcp` or the OpenTelemetry packages in `requirements-semgrep.txt`. Semgrep pins their versions itself, so bumping one of them on its own cannot install.
- Updated kin-openapi, which the code generator uses, from 0.142.0 to 0.149.0. The newer version fixes several panics on malformed specs reported in GitHub security advisories.
- The security scan merges its two gitleaks runs into one SARIF run. GitHub code scanning rejects a report with two runs from the same tool, so no scan results had been uploaded.

## v0.1.2, 2026-10-27

- The development image is based on Debian (`golang:1.26.10-trixie`) instead of Alpine. Alpine keeps only the latest build of each package, so the exact pins broke the image build whenever a package was updated. System packages now come from the snapshot.debian.org date the base image was built from, which keeps them fixed for a given base image digest. jq 1.8.2, shellcheck 0.11.0 and shfmt 3.13.1 keep their versions, and Semgrep runs in its own virtual environment.
- Raised the minimum Go version in `go.mod` from 1.26.9 to 1.26.10, which fixes the `crypto/x509` vulnerability GO-2026-6809 found by govulncheck.
- The issue-pull workflow runs at hours derived from the repository name instead of the same four hours as every other repository.

## v0.1.1, 2026-10-17

- Documentation only. The agent skill explains how to look up every endpoint, parameter and model with `go doc` or on pkg.go.dev, and declares its license.
- The skill no longer lists the API credentials under OpenClaw's `requires.env`, which kept OpenClaw from loading it until they were set. It requires only `go`; the credentials are still documented as what your program reads.
- The README points to the full API reference, and the examples in the README and the skill were checked against the current code.

## v0.1.0, 2026-10-17

- Added `solanatracker`, a REST client generated with oapi-codegen from the Solana Tracker Data API specification, version 1.0.0, OpenAPI 3.1, from https://docs.solanatracker.io/data-api/openapi.json. It covers all 51 paths and 52 operations for token search, prices, holders, trades, charts, wallet data, profit and loss, statistics, credits and subscriptions.
- Added `ws`, package `solanatrackerws`, generated with gen-asyncapi from the Datastream WebSocket specification, version 5.0.0, AsyncAPI 3.0, from https://docs.solanatracker.io/datastream/asyncapi.json. It covers all 43 channels for room subscriptions and streaming market, wallet and Jupiter DCA events.
- Number fields are `float64`. Spec patches preserve nullable fields and mixed cursor types, and normalize server-oriented inline WebSocket messages for client generation and room matching.
- Added offline REST and WebSocket decoding tests, development tooling and the `go-solana-tracker` agent skill. `make generate` downloads both source specs into the gitignored `api/` directory; neither spec is redistributed.
