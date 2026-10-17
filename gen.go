// Package solanatracker is a Go client for the Solana Tracker Data API,
// generated with oapi-codegen from the provider's OpenAPI document.
package solanatracker

//go:generate bash scripts/fetch-spec.sh
//go:generate bash scripts/patch-spec.sh
//go:generate go tool oapi-codegen --config=config.yaml api/openapi.fixed.json
