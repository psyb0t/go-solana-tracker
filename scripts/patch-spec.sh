#!/bin/bash
# Converts OpenAPI 3.1 type lists to OpenAPI 3.0 schemas for oapi-codegen.
# Nullable single types become type + nullable. The integer/string/null cursor
# becomes nullable anyOf, preserving both wire types. The version is set to
# 3.0.3 after conversion. No operations or response schemas are removed.
# Keep generated descriptions plain by normalizing punctuation and filler.
set -euo pipefail
trap 'printf "patch-spec failed at line %s\n" "$LINENO" >&2' ERR

LOG_FILE="${LOG_FILE:-/tmp/patch-spec.log}"
exec > >(tee -a "$LOG_FILE") 2>&1

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/api"
readonly SPEC_DIR

log() {
	jq -nc --arg time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
		--arg file "${BASH_SOURCE[1]##*/}" \
		--arg line "${BASH_LINENO[0]}" --arg func "${FUNCNAME[1]}" \
		--arg msg "$*" \
		'{time:$time,level:"INFO",file:$file,line:($line|tonumber),func:$func,msg:$msg}' >&2
}

main() {
	local tmp
	tmp="$(mktemp "${SPEC_DIR}/.openapi.fixed.XXXXXX")"
	# shellcheck disable=SC2064 # expand tmp before the local goes away
	trap "rm -f -- '${tmp}'" EXIT

	jq '
		walk(if type == "object" and (.type? | type == "array") then
			.type as $types
			| ($types | map(select(. != "null"))) as $nonNull
			| del(.type)
			| if ($types | index("null")) != null then .nullable = true
			  else . end
			| if ($nonNull | length) == 1 then .type = $nonNull[0]
			  else .anyOf = ($nonNull | map({type: .})) end
		else . end)
		| .openapi = "3.0.3"
		| walk(if type == "object" and (.description? | type == "string")
			then .description |=
				(gsub(" *[\u2013\u2014] *"; ", ") | gsub("comprehensive "; ""))
			else . end)
	' "${SPEC_DIR}/openapi.json" >"$tmp"
	chmod 0644 "$tmp"
	mv -- "$tmp" "${SPEC_DIR}/openapi.fixed.json"
	log "normalized OpenAPI type lists"
}

main "$@"
