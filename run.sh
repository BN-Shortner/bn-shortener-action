#!/usr/bin/env bash
# The BN Shortener GitHub Action (action.yml). Runs the bn command shipped next to it. Also runs outside GitHub:
# tests/test_cli.py sets the GITHUB_OUTPUT / GITHUB_STEP_SUMMARY files itself.
set -euo pipefail
: "${BN_API_KEY:?api-key is required}"
OUT=${GITHUB_OUTPUT:-/dev/null}
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
BN_CLI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bn"  # shipped with the action: nothing is downloaded
bn() { python3 "$BN_CLI" "$@"; }

multiline() {  # name, value: a GitHub output that may span lines
    local d="EOF_$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
    { echo "$1<<$d"; printf '%s\n' "$2"; echo "$d"; } >> "$OUT"
}
lines() { printf '%s\n' "$1" | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v -e '^$' -e '^#' || true; }

case "${INPUT_COMMAND:-}" in
shorten)
    [ -n "${INPUT_URLS:-}" ] || { echo "::error::urls is required for shorten"; exit 1; }
    all=(); json="["
    while IFS= read -r url; do
        opts=()
        [ -n "${INPUT_TITLE:-}" ] && opts+=(--title "$INPUT_TITLE")
        [ -n "${INPUT_TAGS:-}" ] && opts+=(--tags "$INPUT_TAGS")
        r=$(bn shorten "$url" "${opts[@]}" --json)
        short=$(printf '%s' "$r" | python3 -c 'import json,sys; print(json.load(sys.stdin)["short_url"])')
        all+=("$short"); json+="$r,"
        echo "$url -> $short"
        echo "- $short ← $url" >> "$SUMMARY"
    done < <(lines "$INPUT_URLS")
    json="${json%,}]"
    [ ${#all[@]} -gt 0 ] || { echo "::error::urls has no URL (only blank or # lines)"; exit 1; }
    echo "short-url=${all[0]}" >> "$OUT"
    multiline short-urls "$(printf '%s\n' "${all[@]}")"
    multiline json "$json"
    ;;
check)
    [ -n "${INPUT_LINKS:-}" ] || { echo "::error::links is required for check"; exit 1; }
    worst=ready; json="["; failed=0
    echo "| Link | Launch Check | To fix |" >> "$SUMMARY"; echo "|---|---|---|" >> "$SUMMARY"
    while IFS= read -r ref; do
        set +e; r=$(bn check "$ref" --json); code=$?; set -e
        # exit 1 is also "not ready": only a JSON answer with a verdict counts as a check that ran
        if ! printf '%s' "$r" | python3 -c 'import json,sys; sys.exit(0 if "verdict" in json.load(sys.stdin) else 1)' 2>/dev/null; then
            echo "::error::bn check $ref failed (exit $code)"; exit $(( code > 0 ? code : 1 ))
        fi
        line=$(printf '%s' "$r" | python3 -c '
import json, sys
r = json.load(sys.stdin)
bad = [c for c in r.get("results") or [] if c.get("status") in ("fail", "warn")]
print(r.get("verdict", "?"), "|", "; ".join(str(c.get("name")) + ": " + str(c.get("fix") or c.get("summary")) for c in bad).replace("|", "/"))')
        verdict=${line%% |*}; fixes=${line#*| }
        echo "$ref: $verdict"
        echo "| $ref | $verdict | ${fixes:-} |" >> "$SUMMARY"
        [ "$verdict" = not_ready ] && { worst=not_ready; failed=1; echo "::error::$ref is not ready: $fixes"; }
        [ "$verdict" = warnings ] && { [ "$worst" = ready ] && worst=warnings; echo "::warning::$ref: $fixes"; }
        json+="$r,"
    done < <(lines "$INPUT_LINKS")
    echo "verdict=$worst" >> "$OUT"
    multiline json "${json%,}]"
    if [ "$failed" = 1 ] || { [ "${INPUT_STRICT:-false}" = true ] && [ "$worst" != ready ]; }; then exit 1; fi
    ;;
run)
    read -r -a argv <<< "${INPUT_ARGS:-}"
    r=$(bn "${argv[@]}")
    printf '%s\n' "$r"
    multiline json "$r"
    ;;
*)
    echo "::error::command must be shorten, check or run"; exit 1 ;;
esac
