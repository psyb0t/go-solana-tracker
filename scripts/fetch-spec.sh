#!/bin/bash
# Downloads the Solana Tracker OpenAPI spec into api/. The spec is not committed;
# `go generate` fetches it as its first step.
set -euo pipefail
trap 'on_error "$?" "$LINENO"' ERR

LOG_FILE="${LOG_FILE:-/tmp/$(basename "$0" .sh).log}"
exec > >(tee -a "$LOG_FILE") 2>&1

readonly SPEC_NAME="${1:-openapi.json}"
case "$SPEC_NAME" in
openapi.json) SPEC_URL="https://docs.solanatracker.io/data-api/openapi.json" ;;
asyncapi.json) SPEC_URL="https://docs.solanatracker.io/datastream/asyncapi.json" ;;
*)
	printf 'Unknown spec: %s\n' "$SPEC_NAME" >&2
	exit 1
	;;
esac
readonly SPEC_URL
readonly DOWNLOAD_TIMEOUT_SECONDS=60
SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/api"
readonly SPEC_DIR

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

main() {
	mkdir -p "$SPEC_DIR"
	local tmp
	tmp="$(mktemp "${SPEC_DIR}/.${SPEC_NAME}.XXXXXX")"
	# shellcheck disable=SC2064 # expand tmp now, the local is gone when EXIT fires
	trap "rm -f -- '${tmp}'" EXIT

	log INFO "downloading spec=${SPEC_NAME}"
	wget -q \
		-T "$DOWNLOAD_TIMEOUT_SECONDS" \
		-O "$tmp" \
		"$SPEC_URL"

	if ! jq -e '(.openapi == "3.1.0" or .asyncapi == "3.0.0") and
		(.info | type == "object")' "$tmp" >/dev/null; then
		log ERROR "downloaded file is not a supported API document spec=${SPEC_NAME}"
		exit 1
	fi

	chmod 0644 "$tmp"
	mv -- "$tmp" "${SPEC_DIR}/${SPEC_NAME}"
	log INFO "saved spec=${SPEC_NAME}"
}

main "$@"
