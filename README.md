# go-solana-tracker

[![Go Reference](https://pkg.go.dev/badge/github.com/psyb0t/go-solana-tracker.svg)](https://pkg.go.dev/github.com/psyb0t/go-solana-tracker)
[![CI](https://github.com/psyb0t/go-solana-tracker/actions/workflows/pipeline.yml/badge.svg?branch=main)](https://github.com/psyb0t/go-solana-tracker/actions/workflows/pipeline.yml)
[![version](https://raw.githubusercontent.com/psyb0t/go-solana-tracker/badges/version.svg)](https://github.com/psyb0t/go-solana-tracker/tags)
[![license](https://raw.githubusercontent.com/psyb0t/go-solana-tracker/badges/license.svg)](LICENSE)
[![imported by](https://raw.githubusercontent.com/psyb0t/go-solana-tracker/badges/importers.svg)](https://github.com/psyb0t/go-solana-tracker/blob/badges/importers.md)

Unofficial Go client for the [Solana Tracker Data API](https://docs.solanatracker.io/data-api) and [Datastream WebSocket API](https://docs.solanatracker.io/datastream), generated with [oapi-codegen](https://github.com/oapi-codegen/oapi-codegen) and [gen-asyncapi](https://github.com/psyb0t/gen-asyncapi) from the specifications Solana Tracker publishes. I am not affiliated with Solana Tracker.

The REST package is `solanatracker`, in the repository root. The `ws` subpackage is `solanatrackerws`. Generated files come from the specs. Don't edit them by hand, regenerate them.

## Install

```sh
go get github.com/psyb0t/go-solana-tracker
```

## Usage

Every REST endpoint in the spec has a typed method on `ClientWithResponses`. Responses decode into `JSON200` and the other status fields.

```go
package main

import (
	"context"
	"net/http"
	"os"

	solanatracker "github.com/psyb0t/go-solana-tracker"
)

func main() {
	auth := solanatracker.WithRequestEditorFn(
		func(_ context.Context, req *http.Request) error {
			req.Header.Set("x-api-key", os.Getenv("SOLANA_TRACKER_API_KEY"))

			return nil
		},
	)

	client, err := solanatracker.NewClientWithResponses(
		"https://data.solanatracker.io",
		auth,
	)
	if err != nil {
		panic(err)
	}

	res, err := client.GetPriceWithResponse(
		context.Background(),
		&solanatracker.GetPriceParams{Token: "TOKEN_ADDRESS"},
	)
	if err != nil {
		panic(err)
	}

	if res.JSON200 == nil {
		panic(res.Status())
	}

	_ = res.JSON200.Price
}
```

The same code is in `example_test.go`, so `make test` checks that it compiles. Replace `TOKEN_ADDRESS` with the token mint address. HTTP error statuses do not become Go errors automatically.

The full API, with the spec's descriptions as doc comments, is in the [Go reference](https://pkg.go.dev/github.com/psyb0t/go-solana-tracker) and in `go doc github.com/psyb0t/go-solana-tracker` (or `.../ws` for Datastream) from inside your module.

The REST client covers token search, prices and history, holders, charts, trades, wallet balances and activity, profit and loss, market statistics, credits and subscription details. Generated names follow HTTP methods and paths because the spec has no operation IDs.

## Auth

The Data API uses the `x-api-key` header at `https://data.solanatracker.io`. The request editor above reads the key from `SOLANA_TRACKER_API_KEY`. Use `WithHTTPClient` with your own `http.Client` to set timeouts.

Datastream connects to `wss://datastream.solanatracker.io/{apiKey}` and requires a Premium, Business or Enterprise plan. Never log the connection URL. The `ws` package generates room commands, typed event handlers and decoding for all 43 channels, including token and pool prices, transactions, wallet activity and Jupiter DCA events.

## Regenerating

The specs are not committed. `make generate` downloads the current documents into the gitignored `api/` directory and regenerates both clients:

```sh
make generate
```

`gen.go` and `ws/gen.go` declare the steps, discovered by `go generate ./...`:

- `scripts/fetch-spec.sh` downloads [OpenAPI](https://docs.solanatracker.io/data-api/openapi.json) and [AsyncAPI](https://docs.solanatracker.io/datastream/asyncapi.json).
- `scripts/patch-spec.sh` converts nullable type lists into 3.0 schemas. A cursor accepting integers and strings becomes a nullable `anyOf`, preserving both wire types. The output declares OpenAPI 3.0.3 for oapi-codegen.
- oapi-codegen uses `config.yaml`, mapping `number` to `float64`.
- `scripts/patch-asyncapi.sh` changes server operation directions to client directions, hoists inline messages, adds room constraints for event matching, shares identical price messages and adds receive operations for joined acknowledgements. Balance amounts become `number` because the provider's examples contain fractions despite an integer schema. Required DCA event and position fields distinguish otherwise ambiguous union variants. gen-asyncapi uses `ws/config.yaml`.

`.github/workflows/regen.yml` does the same every day in CI. When the new spec changes the client, it runs `make lint`, `make test` and `make sec`. If a check fails, Claude edits the code and the checks run again, up to three times, and a review step reads the result. A passing change is committed with a CHANGELOG entry and tagged as the next release: a patch version for fixes and additions, a minor version for breaking changes.

## Agent integrations

The [skill](.agents/skills/go-solana-tracker) teaches a coding agent how to use go-solana-tracker when it writes Go. Agents that read `.agents/skills/` can use it directly from this checkout. After publication to the marketplace, install it in the clients below.

### Claude Code

```bash
claude plugin marketplace add psyb0t/agents
claude plugin install go-solana-tracker@psyb0t
```

### Codex

```bash
codex plugin marketplace add psyb0t/agents
codex plugin add go-solana-tracker@psyb0t
```

Codex also picks the skill up with no install in any checkout of this repo.

### OpenClaw

The release workflow includes publication to ClawHub. After a release publishes the skill:

```bash
openclaw skills install @psyb0t/go-solana-tracker
```

## Development

Every command runs in the `Dockerfile.dev` image. The host needs only Docker and Make.

```sh
make help      # list targets
make dep       # go mod tidy + vendor
make lint      # shellcheck, shfmt, go fix, golangci-lint
make test      # go test -race
make sec       # gitleaks, govulncheck, semgrep
make generate  # download the specs and regenerate
```

## License

[MIT](LICENSE). The generated code comes from Solana Tracker's published API specifications. Neither source document declares a license. The specifications themselves are not redistributed here; API access remains subject to the provider's terms and subscription.
