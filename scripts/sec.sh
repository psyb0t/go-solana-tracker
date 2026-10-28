#!/bin/bash
set -euo pipefail
trap 'on_error "$?" "$LINENO"' ERR

LOG_FILE="${LOG_FILE:-/tmp/$(basename "$0" .sh).log}"
exec > >(tee -a "$LOG_FILE") 2>&1

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

SARIF_OUT="${SARIF_OUT:-sec.sarif}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log INFO "scanning the current worktree for secrets"
gitleaks_dir_rc=0
gitleaks dir --no-banner --no-color --redact \
	--gitleaks-ignore-path /work/.gitleaksignore \
	--report-format sarif \
	--report-path "$tmp/gitleaks-dir.sarif" \
	/work || gitleaks_dir_rc=$?

gitleaks_git_rc=0
if [[ -e /work/.git ]]; then
	log INFO "scanning Git history for secrets"
	gitleaks git --no-banner --no-color --redact \
		--gitleaks-ignore-path /work/.gitleaksignore \
		--report-format sarif \
		--report-path "$tmp/gitleaks-git.sarif" \
		/work || gitleaks_git_rc=$?
else
	log INFO "no Git repository present, skipping the history scan"
	printf '{"version":"2.1.0","runs":[]}\n' >"$tmp/gitleaks-git.sarif"
fi

log INFO "running govulncheck"
# SARIF mode exits 0 even with findings, so it only writes the report; the plain
# text run below is what gates, exiting non-zero on a reachable vulnerability.
govulncheck -format sarif ./... >"$tmp/govulncheck.sarif"
gv_rc=0
govulncheck ./... || gv_rc=$?

log INFO "running semgrep"
# --error gates on a finding; --sarif writes the report; --metrics=off keeps the
# scan from phoning home. One run does both.
sg_rc=0
semgrep_targets=(
	.github
	Dockerfile.dev
	Makefile
	./*.go
	ws
	scripts
)
semgrep scan --config p/golang --config p/security-audit \
	--no-git-ignore --sarif --output "$tmp/semgrep.sarif" \
	--metrics=off --error "${semgrep_targets[@]}" || sg_rc=$?

# encoding/json on an empty interface only builds JSON primitives, arrays and
# maps. Preserve this generated additionalProperties finding with a suppression;
# require the exact rule, file, reported snippet and matching source lines.
semgrep_safe_rule="go.lang.security.deserialization.unsafe-deserialization-interface.go-unsafe-deserialization-interface"
semgrep_safe_snippet=$'\t\t\tvar fieldVal interface{}\n\t\t\terr := json.Unmarshal(fieldBuf, &fieldVal)'
semgrep_safe_justification="oapi-codegen additionalProperties uses encoding/json on an empty interface, which only creates JSON primitives, arrays and maps and cannot instantiate executable types."
# shellcheck disable=SC2016 # These variables are jq names, not shell expansions.
semgrep_suppression_filter='
  .runs |= map(
    .results = ((.results // []) | map(
      if .ruleId == $rule
        and (.locations | length) == 1
        and .locations[0].physicalLocation.artifactLocation.uri == "client.gen.go"
        and .locations[0].physicalLocation.region.snippet.text == $snippet
        and (.locations[0].physicalLocation.region as $region |
          $region.startLine > 0
          and $region.endLine == $region.startLine + 1
          and (($source | split("\n"))[
            $region.startLine - 1:$region.endLine
          ] | join("\n")) == $snippet)
      then .suppressions = ((.suppressions // []) + [{
        kind: "external", justification: $justification
      }])
      else . end
    ))
  )'
jq --arg rule "$semgrep_safe_rule" \
	--arg snippet "$semgrep_safe_snippet" \
	--arg justification "$semgrep_safe_justification" \
	--rawfile source client.gen.go "$semgrep_suppression_filter" \
	"$tmp/semgrep.sarif" >"$tmp/semgrep-reviewed.sarif"

# Exit 1 means findings. Keep scanner/configuration failures, failed
# invocations and error notifications fatal even when findings are suppressed.
if [[ "$sg_rc" -eq 1 ]] && jq -e \
	--arg justification "$semgrep_safe_justification" '
  ([.runs[].results[]?] | length) > 0
  and all(.runs[].invocations[]?;
    .executionSuccessful != false
    and all(.toolExecutionNotifications[]?; .level != "error"))
  and all(.runs[].results[]?;
    any(.suppressions[]?;
      .kind == "external" and .justification == $justification))
  ' "$tmp/semgrep-reviewed.sarif" >/dev/null; then
	log INFO "only the reviewed generated JSON finding remains, recorded as suppressed"
	sg_rc=0
fi

log INFO "merging SARIF"
# Code scanning rejects a file holding two runs from the same tool, so the
# gitleaks directory and history runs are folded into one run per tool.
jq -s '{version:"2.1.0","$schema":"https://json.schemastore.org/sarif-2.1.0.json",runs:([.[].runs // []] | add | group_by(.tool.driver.name) | map(.[0] + {results: (map(.results // []) | add)}))}' \
	"$tmp/gitleaks-dir.sarif" \
	"$tmp/gitleaks-git.sarif" \
	"$tmp/govulncheck.sarif" \
	"$tmp/semgrep-reviewed.sarif" >"$SARIF_OUT"

if [ "$gitleaks_dir_rc" -ne 0 ] || [ "$gitleaks_git_rc" -ne 0 ] ||
	[ "$gv_rc" -ne 0 ] || [ "$sg_rc" -ne 0 ]; then
	log ERROR "security findings, gitleaks_dir=${gitleaks_dir_rc}, gitleaks_git=${gitleaks_git_rc}, govulncheck=${gv_rc}, semgrep=${sg_rc}, report=${SARIF_OUT}"
	exit 1
fi
log INFO "security scan complete with no unsuppressed findings"
