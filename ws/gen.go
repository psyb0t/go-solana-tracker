// Package solanatrackerws provides the Solana Tracker Datastream client.
package solanatrackerws

//go:generate bash ../scripts/fetch-spec.sh asyncapi.json
//go:generate bash ../scripts/patch-asyncapi.sh
//go:generate go tool gen-asyncapi --config=config.yaml ../api/asyncapi.client.json
