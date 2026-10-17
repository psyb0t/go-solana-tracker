package solanatracker_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	solanatracker "github.com/psyb0t/go-solana-tracker"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	testAPIKey       = "EXAMPLE-DO-NOT-USE"
	testTokenAddress = "TOKEN_ADDRESS"
)

func newTestClient(
	t *testing.T,
	handler http.HandlerFunc,
) *solanatracker.ClientWithResponses {
	t.Helper()

	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)

	auth := solanatracker.WithRequestEditorFn(
		func(_ context.Context, req *http.Request) error {
			req.Header.Set("x-api-key", testAPIKey)

			return nil
		},
	)
	client, err := solanatracker.NewClientWithResponses(srv.URL, auth)
	require.NoError(t, err)

	return client
}

func TestGetPrice(t *testing.T) {
	t.Parallel()

	client := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodGet, r.Method)
		assert.Equal(t, "/price", r.URL.Path)
		assert.Equal(t, testTokenAddress, r.URL.Query().Get("token"))
		assert.Equal(t, testAPIKey, r.Header.Get("x-api-key"))

		w.Header().Set("Content-Type", "application/json")
		_, err := w.Write([]byte(`{"price":1.123456789,"liquidity":25.5}`))
		assert.NoError(t, err)
	})

	res, err := client.GetPriceWithResponse(
		context.Background(),
		&solanatracker.GetPriceParams{Token: testTokenAddress},
	)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, res.StatusCode())
	require.NotNil(t, res.JSON200)
	require.NotNil(t, res.JSON200.Price)
	assert.InDelta(t, 1.123456789, *res.JSON200.Price, 0)
}

func TestPostPriceMulti(t *testing.T) {
	t.Parallel()

	client := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/price/multi", r.URL.Path)
		assert.Equal(t, testAPIKey, r.Header.Get("x-api-key"))
		assert.Equal(t, "application/json", r.Header.Get("Content-Type"))

		var body solanatracker.PostPriceMultiJSONRequestBody

		assert.NoError(t, json.NewDecoder(r.Body).Decode(&body))
		assert.Equal(t, []string{testTokenAddress}, body.Tokens)

		w.Header().Set("Content-Type", "application/json")
		_, err := w.Write([]byte(`{"TOKEN_ADDRESS":{"price":2.25}}`))
		assert.NoError(t, err)
	})

	res, err := client.PostPriceMultiWithResponse(
		context.Background(),
		solanatracker.PostPriceMultiJSONRequestBody{
			Tokens: []string{testTokenAddress},
		},
	)
	require.NoError(t, err)
	require.NotNil(t, res.JSON200)
	price := (*res.JSON200)[testTokenAddress]
	require.NotNil(t, price.Price)
	assert.InDelta(t, 2.25, *price.Price, 0)
}

func TestUnauthorized(t *testing.T) {
	t.Parallel()

	srv := httptest.NewServer(http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			assert.Empty(t, r.Header.Get("x-api-key"))
			w.WriteHeader(http.StatusUnauthorized)
		},
	))
	t.Cleanup(srv.Close)

	client, err := solanatracker.NewClientWithResponses(srv.URL)
	require.NoError(t, err)
	res, err := client.GetSubscriptionWithResponse(context.Background())
	require.NoError(t, err)
	assert.Equal(t, http.StatusUnauthorized, res.StatusCode())
	assert.Nil(t, res.JSON200)
}

func TestMalformedResponse(t *testing.T) {
	t.Parallel()

	client := newTestClient(t, func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, err := w.Write([]byte(`{"price":`))
		assert.NoError(t, err)
	})

	_, err := client.GetPriceWithResponse(
		context.Background(),
		&solanatracker.GetPriceParams{Token: testTokenAddress},
	)

	var syntaxError *json.SyntaxError

	require.ErrorAs(t, err, &syntaxError)
}

func TestTradeCursorWireTypes(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name string
		body string
	}{
		{"timestamp", `{"nextCursor":42}`},
		{"opaque", `{"nextCursor":"CURSOR_VALUE"}`},
		{"end", `{"nextCursor":null}`},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			var response solanatracker.TokenTradesResponse

			require.NoError(t, json.Unmarshal([]byte(tc.body), &response))

			var expected map[string]json.RawMessage

			require.NoError(t, json.Unmarshal([]byte(tc.body), &expected))

			encoded, err := json.Marshal(response.NextCursor)
			require.NoError(t, err)
			assert.JSONEq(t, string(expected["nextCursor"]), string(encoded))
		})
	}
}

func TestNullableEnrichment(t *testing.T) {
	t.Parallel()

	var pnl solanatracker.EnrichedTokenPnl

	require.NoError(t, json.Unmarshal([]byte(`{
		"firstBuy":null,"lastBuy":42,"firstSell":null,"lastSell":null,
		"firstTrade":null,"lastTrade":null,"avgCost":null,"holdTimeSecs":null
	}`), &pnl))
	assert.Nil(t, pnl.FirstBuy)
	assert.Nil(t, pnl.FirstSell)
	assert.Nil(t, pnl.LastSell)
	assert.Nil(t, pnl.FirstTrade)
	assert.Nil(t, pnl.LastTrade)
	assert.Nil(t, pnl.AvgCost)
	assert.Nil(t, pnl.HoldTimeSecs)
	require.NotNil(t, pnl.LastBuy)
	assert.Equal(t, 42, *pnl.LastBuy)

	var identity solanatracker.EnrichedIdentity

	require.NoError(t, json.Unmarshal([]byte(`{
		"bot":{"name":null,"avatar":null}
	}`), &identity))
	require.NotNil(t, identity.Bot)
	assert.Nil(t, identity.Bot.Name)
	assert.Nil(t, identity.Bot.Avatar)
}

func TestHoldersPagination(t *testing.T) {
	t.Parallel()

	client := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodGet, r.Method)
		assert.Equal(t, "/tokens/TOKEN_ADDRESS/holders/paginated", r.URL.Path)
		assert.Equal(t, testAPIKey, r.Header.Get("x-api-key"))
		assert.Equal(t, "1", r.URL.Query().Get("limit"))
		w.Header().Set("Content-Type", "application/json")

		body := `{
			"total":2,"accounts":[{"wallet":"HOLDER_A"}],
			"cursor":"NEXT_PAGE","hasMore":true,"limit":1
		}`

		if r.URL.Query().Get("cursor") != "" {
			assert.Equal(t, "NEXT_PAGE", r.URL.Query().Get("cursor"))

			body = `{
				"total":2,"accounts":[{"wallet":"HOLDER_B"}],
				"cursor":null,"hasMore":false,"limit":1
			}`
		}

		_, err := w.Write([]byte(body))
		assert.NoError(t, err)
	})

	limit := 1
	params := &solanatracker.GetTokensTokenAddressHoldersPaginatedParams{
		Limit: &limit,
	}

	const expectedHolders = 2

	var wallets []string

	for range expectedHolders {
		res, err := client.GetTokensTokenAddressHoldersPaginatedWithResponse(
			context.Background(), testTokenAddress, params,
		)
		require.NoError(t, err)
		require.NotNil(t, res.JSON200)
		assert.Equal(t, expectedHolders, res.JSON200.Total)

		for _, holder := range res.JSON200.Accounts {
			wallets = append(wallets, holder.Wallet)
		}

		params.Cursor = res.JSON200.Cursor
		if !res.JSON200.HasMore {
			break
		}
	}

	assert.Nil(t, params.Cursor)
	assert.Equal(t, []string{"HOLDER_A", "HOLDER_B"}, wallets)
}
