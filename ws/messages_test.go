package solanatrackerws_test

import (
	"context"
	"encoding/json"
	"os"
	"testing"

	"github.com/psyb0t/ctxerrors/commerr"
	"github.com/psyb0t/gen-asyncapi/asyncapirt"
	solanatrackerws "github.com/psyb0t/go-solana-tracker/ws"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const holdersRoom = "holders:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

func TestDecodeReceivedMessages(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		file string
		name string
	}{
		{"holders.json", solanatrackerws.MessageHoldersMessage},
		{"balance.json", solanatrackerws.MessageBalanceMessage},
		{"balance-integer.json", solanatrackerws.MessageBalanceMessage},
		{"dca-filled.json", solanatrackerws.MessageDcaJupiterMessage},
		{"dca-position.json", solanatrackerws.MessageDcaJupiterMessage},
		{
			"dca-scoped-filled.json",
			solanatrackerws.MessageDcaJupiterMintBuyersMessage,
		},
		{
			"aggregated-price.json",
			solanatrackerws.MessagePriceAggregatedMessage,
		},
		{"pool-price.json", solanatrackerws.MessagePricePoolMessage},
		{"holders-joined.json", solanatrackerws.MessageHoldersJoined},
	}

	for _, tc := range testCases {
		t.Run(tc.file, func(t *testing.T) {
			t.Parallel()

			frame, err := os.ReadFile("testdata/" + tc.file)
			require.NoError(t, err)

			message, err := solanatrackerws.DecodeReceivedMessage(frame)
			require.NoError(t, err)
			assert.Equal(t, tc.name, message.Name)

			encoded, err := json.Marshal(message.Payload)
			require.NoError(t, err)
			assert.JSONEq(t, string(frame), string(encoded))
		})
	}
}

func TestDecodeRejectsInvalidFrames(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name string
		data string
		err  error
	}{
		{"malformed", "{", commerr.ErrCouldNotDecode},
		{"unknown type", `{"type":"unlisted"}`, asyncapirt.ErrUnknownMessage},
		{
			"missing room",
			`{"type":"message","data":{"total":42}}`,
			asyncapirt.ErrUnknownMessage,
		},
		{
			"invalid room",
			`{"type":"message","room":"holders:../private"}`,
			asyncapirt.ErrUnknownMessage,
		},
		{
			"unknown DCA event",
			`{
				"type":"message",
				"room":"dca:jupiter",
				"data":{"eventName":"unlisted"}
			}`,
			asyncapirt.ErrNoVariantMatched,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			_, err := solanatrackerws.DecodeReceivedMessage([]byte(tc.data))
			require.ErrorIs(t, err, tc.err)
		})
	}
}

type recordingTransport struct {
	sent [][]byte
}

func (r *recordingTransport) WriteMessage(
	_ context.Context,
	data []byte,
) error {
	r.sent = append(r.sent, data)

	return nil
}

func (r *recordingTransport) ReadMessage(context.Context) ([]byte, error) {
	return nil, context.Canceled
}

func (r *recordingTransport) Close() error {
	return nil
}

func TestSubscribeSendsClientCommand(t *testing.T) {
	t.Parallel()

	transport := &recordingTransport{}
	client := solanatrackerws.NewClient(transport)

	err := client.SubscribeToHolders(
		context.Background(),
		solanatrackerws.JoinHoldersPayload{Room: holdersRoom},
	)
	require.NoError(t, err)
	require.Len(t, transport.sent, 1)
	assert.JSONEq(t, `{
		"type":"join",
		"room":"holders:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
	}`, string(transport.sent[0]))
}

func TestSubscribeRejectsInvalidRoom(t *testing.T) {
	t.Parallel()

	transport := &recordingTransport{}
	client := solanatrackerws.NewClient(transport)

	err := client.SubscribeToHolders(
		context.Background(),
		solanatrackerws.JoinHoldersPayload{Room: "holders:../private"},
	)
	require.ErrorIs(t, err, commerr.ErrValidationFailed)
	assert.Empty(t, transport.sent)
}
