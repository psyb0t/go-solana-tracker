package solanatracker_test

import (
	"context"
	"net/http"
	"os"

	solanatracker "github.com/psyb0t/go-solana-tracker"
)

// This README example requires a subscription key and only compiles in tests.
//
//nolint:testableexamples // requires real credentials, compile check only
func Example() {
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
