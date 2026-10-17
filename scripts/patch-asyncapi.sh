#!/bin/bash
# The provider describes the server, so swap operation actions for a client.
# Reuse each join command's room constraints in its server envelopes. Most
# envelopes omit those constraints, making unrelated frames indistinguishable.
# Require envelope type and room, which the room protocol always sends.
# Hoist inline messages for stable names. Two price channels have identical
# wire schemas, so share their update and acknowledgement components.
# Add receive operations for joined acknowledgements omitted from operations.
# Normalize dash punctuation in summaries copied into generated comments.
# BalanceUpdate.amount is declared integer, but the provider's balance examples
# contain fractional token amounts. Use number so both forms decode as float64.
# DCA union variants omit required fields, so every event also matches the
# position snapshot. Require the examples' identifying fields: eventName for
# events, and pubkey plus writeVersion for position snapshots.
set -euo pipefail
trap 'on_error "$?" "$LINENO"' ERR

LOG_FILE="${LOG_FILE:-/tmp/$(basename "$0" .sh).log}"
exec > >(tee -a "$LOG_FILE") 2>&1

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/api"
readonly SPEC_DIR
readonly SOURCE="${SPEC_DIR}/asyncapi.json"
readonly OUTPUT="${SPEC_DIR}/asyncapi.client.json"

on_error() {
	local exit_code="$1"
	local line="$2"

	printf '{"level":"ERROR","file":"%s","line":%d,"msg":"command failed","exit_code":%d}\n' \
		"${BASH_SOURCE[1]}" "$line" "$exit_code" >&2
}

log() {
	local level="$1"
	shift

	jq -nc \
		--arg time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
		--arg level "$level" \
		--arg file "${BASH_SOURCE[1]##*/}" \
		--arg line "${BASH_LINENO[0]}" \
		--arg func "${FUNCNAME[1]:-main}" \
		--arg msg "$*" \
		'{time:$time,level:$level,file:$file,line:($line|tonumber),func:$func,msg:$msg}' >&2
}

if [[ $# -ne 0 ]]; then
	printf 'Usage: %s\n' "$(basename "$0")" >&2
	exit 2
fi
if [[ ! -s "$SOURCE" ]]; then
	log ERROR "source AsyncAPI spec missing"
	exit 1
fi

tmp="$(mktemp "${SPEC_DIR}/.asyncapi.XXXXXX")"
trap 'rm -f -- "$tmp"' EXIT

log INFO "patching client AsyncAPI document"
jq '
  def canonical:
    if . == "priceAllMessage" then "pricePoolMessage"
    elif . == "priceAllJoined" then "pricePoolJoined"
    else . end;
  .components.schemas.BalanceUpdate.properties.amount.type = "number"
  | .components.schemas |= with_entries(
      if (.value.properties.eventName.const? != null) then
        .value.required =
          (((.value.required // []) + ["eventName"]) | unique)
      elif .key == "DcaPositionEvent" then
        .value.required =
          (((.value.required // []) + ["pubkey", "writeVersion"]) | unique)
      else . end)
  | .operations |= with_entries(.value.action |=
    if . == "send" then "receive" else "send" end)
  | .channels |= with_entries(
      (.value.messages | to_entries
        | map(select(.value.payload.properties.type.const == "join"))
        | .[0].value.payload.properties.room) as $room
      | .value.messages |= with_entries(
          .value.payload.properties.room = $room
          | .value.payload.required =
            (((.value.payload.required // []) + ["type", "room"]) | unique)))
  | reduce (.channels | to_entries[]) as $channel (. ;
      reduce ($channel.value.messages | to_entries[]) as $message (. ;
        ($message.key | canonical) as $name
        | .components.messages[$name] = $message.value
        | .channels[$channel.key].messages[$message.key] =
            {"$ref": ("#/components/messages/" + $name)}
        | if $message.value.payload.properties.type.const == "joined" then
            .operations["receive" + $channel.key + "Joined"] = {
              action: "receive",
              channel: {"$ref": ("#/channels/" + $channel.key)},
              messages: [{"$ref": ("#/channels/" + $channel.key
                + "/messages/" + $message.key)}]
            }
          else . end))
  | walk(if type == "object" and (.summary? | type == "string")
      then .summary |= gsub(" *[\u2013\u2014] *"; ", ")
      else . end)
' "$SOURCE" >"$tmp"
chmod 0644 "$tmp"
mv -- "$tmp" "$OUTPUT"
log INFO "saved client AsyncAPI document"
