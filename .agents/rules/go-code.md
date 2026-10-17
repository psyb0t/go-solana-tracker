# Go code

Refines `~/.claude/rule-details/go/wrapping-errors.md` and `~/.claude/rule-details/coding-style.md`.

- **GO1** `client.gen.go` and `ws/solanatrackerws.gen.go` are generated. Never edit them by hand. Change the generator configuration or the spec patch in `scripts/`, then run `make generate`.
- **GO2** Spec fixes live in `scripts/`, applied to the downloaded specs before generation, including OpenAPI 3.1 downconversion and AsyncAPI normalization. Each patch says in its header which spec problem it fixes.
- **GO3** The downloaded spec in `api/` is gitignored and never committed.
- **GO4** Number fields stay `float64` through the `type-mapping` in `config.yaml`. Money in `float32` loses precision.
- **GO5** Hand-written Go (`gen.go` and the tests) wraps errors with `ctxerrors.Wrap` against `ctxerrors/commerr` sentinels. No `fmt.Errorf`, no `errors.New` outside a sentinel declaration.
- **GO6** The exported API is whatever oapi-codegen and gen-asyncapi emit. A config change that renames or removes an exported name is a breaking release (see `releases.md`).
- **GO7** `make lint` passes with zero issues. Hand-written lines are at most 80 columns, the `.golangci.yml` limit.
