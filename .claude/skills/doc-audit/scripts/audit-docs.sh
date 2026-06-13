#!/usr/bin/env bash
# audit-docs.sh — deterministic documentation-completeness audit for the
# claude-plugins marketplace. PURE DETECTION: never edits files.
# Usage: audit-docs.sh [--root DIR] [--format pretty|tsv]
set -euo pipefail

# ---- globals (set by main) -------------------------------------------------
ROOT=""; MARKETPLACE=""; FORMAT="pretty"
declare -a FINDINGS=()
declare -a COVERAGE=()
ERROR_COUNT=0; WARN_COUNT=0; INFO_COUNT=0

add_finding() { # severity layer plugin code message
  FINDINGS+=("$1"$'\t'"$2"$'\t'"$3"$'\t'"$4"$'\t'"$5")
  case "$1" in
    ERROR) ERROR_COUNT=$((ERROR_COUNT+1)) ;;
    WARN)  WARN_COUNT=$((WARN_COUNT+1)) ;;
    INFO)  INFO_COUNT=$((INFO_COUNT+1)) ;;
  esac
}

# ---- pure helpers ----------------------------------------------------------
fm_get() { # SKILL.md key -> value (empty if absent)
  awk -v k="$2" '
    NR==1 && $0=="---"{infm=1; next}
    infm && $0=="---"{exit}
    infm{
      i=index($0,":"); if(i<1) next
      key=substr($0,1,i-1); gsub(/^[ \t]+|[ \t]+$/,"",key)
      if(key==k){ v=substr($0,i+1); gsub(/^[ \t]+|[ \t]+$/,"",v);
                  gsub(/^["'\'']|["'\'']$/,"",v); print v; exit }
    }' "$1"
}

list_plugins() { # -> name<TAB>source<TAB>version<TAB>description
  if command -v jq >/dev/null 2>&1; then
    jq -r '.plugins[]|[.name,.source,(.version|tostring),(.description//"")]|@tsv' "$MARKETPLACE"
  else
    python3 - "$MARKETPLACE" <<'PY'
import json,sys
for p in json.load(open(sys.argv[1]))["plugins"]:
    print("\t".join([p["name"],p["source"],str(p["version"]),p.get("description","")]))
PY
  fi
}

json_field() { # file key(top-level) -> value
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$2" '.[$k]//""' "$1"
  else
    python3 - "$1" "$2" <<'PY'
import json,sys
print(json.load(open(sys.argv[1])).get(sys.argv[2],""))
PY
  fi
}

plugin_skills() { # plugin_dir -> name<TAB>userInvocable<TAB>disableModel<TAB>desc
  local d="$1" s nm ui dmi desc
  for s in "$d"/skills/*/SKILL.md; do
    [[ -f "$s" ]] || continue
    nm="$(fm_get "$s" name)"; [[ -n "$nm" ]] || nm="$(basename "$(dirname "$s")")"
    ui="$(fm_get "$s" user-invocable)"; [[ -n "$ui" ]] || ui="true"
    dmi="$(fm_get "$s" disable-model-invocation)"; [[ -n "$dmi" ]] || dmi="false"
    desc="$(fm_get "$s" description)"
    printf '%s\t%s\t%s\t%s\n' "$nm" "$ui" "$dmi" "$desc"
  done
}

num_to_word() { # n -> english word (1..12) or the number itself
  case "$1" in
    1) echo one;; 2) echo two;; 3) echo three;; 4) echo four;; 5) echo five;;
    6) echo six;; 7) echo seven;; 8) echo eight;; 9) echo nine;; 10) echo ten;;
    11) echo eleven;; 12) echo twelve;; *) echo "$1";;
  esac
}

# ---- layer checks (filled in by later tasks) -------------------------------
check_plugin_skills() { # name dir   (layer ①)
  local name="$1" dir="$2"
  local readme="$dir/README.md"
  local text="" has_user=0 any_undocumented=0 valid sk ui dmi desc cmd
  [[ -f "$readme" ]] && text="$(cat "$readme")"
  valid="$(plugin_skills "$dir" | cut -f1)"
  while IFS=$'\t' read -r sk ui dmi desc; do
    cmd="/$name:$sk"
    if [[ "$ui" == "false" ]]; then
      COVERAGE+=("$name  $cmd  (internal)")
      continue
    fi
    has_user=1
    if grep -qF "$cmd" <<<"$text"; then
      COVERAGE+=("$name  $cmd  documented")
    else
      COVERAGE+=("$name  $cmd  MISSING")
      any_undocumented=1
      add_finding ERROR 1 "$name" CMD_NOT_IN_README \
        "user command $cmd is not documented in $name/README.md"
      continue
    fi
    if [[ "$dmi" == "true" ]] \
       && ! grep -F "$cmd" <<<"$text" | grep -iE "(destructive|user-invoked)" >/dev/null; then
      add_finding WARN 1 "$name" MARKER_MISSING \
        "$cmd is user-invoked only but its README entry lacks a destructive/user-invoked marker"
    fi
  done < <(plugin_skills "$dir")

  if [[ "$has_user" == "1" && "$any_undocumented" == "1" ]] \
     && ! grep -qE '^##[[:space:]]+Skills' <<<"$text"; then
    add_finding WARN 1 "$name" MISSING_SKILLS_SECTION \
      "$name/README.md has undocumented user commands and no '## Skills' section to surface them"
  fi

  local suffix
  while IFS= read -r suffix; do
    [[ -n "$suffix" ]] || continue
    if ! grep -qxF "$suffix" <<<"$valid"; then
      add_finding WARN 1 "$name" PHANTOM_CMD \
        "$name/README.md documents /$name:$suffix but no matching SKILL.md exists"
    fi
  done < <(grep -oE "/$name:[a-z0-9-]+" <<<"$text" | sed "s#/$name:##" | sort -u)
}
check_root_readme() { # layer ②
  local readme="$ROOT/README.md" text="" name src ver desc count=0 word
  [[ -f "$readme" ]] && text="$(cat "$readme")"
  while IFS=$'\t' read -r name src ver desc; do
    count=$((count+1))
    if ! grep -qF "$name" <<<"$text"; then
      add_finding ERROR 2 "$name" PLUGIN_NOT_IN_ROOT \
        "plugin '$name' is registered but not mentioned in the root README"
    fi
  done < <(list_plugins)
  word="$(num_to_word "$count")"
  if grep -qiE '\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|[0-9]+) plugins\b' <<<"$text" \
     && ! grep -qiE "\b(${word}|${count}) plugins\b" <<<"$text"; then
    add_finding WARN 2 "" ROOT_COUNT_STALE \
      "root README states a plugin count that doesn't match the actual ${count} plugins"
  fi
  if ! grep -qiE '^#{2,3}[[:space:]].*command' <<<"$text"; then
    add_finding WARN 2 "" ROOT_NO_CMD_INDEX \
      "root README has no central command index (a '## Commands' section listing every plugin's slash commands)"
  fi
}
check_manifest_sync() { # name dir mp_version mp_description   (layer ③)
  local name="$1" dir="$2" mver="$3" mdesc="$4"
  local pj="$dir/.claude-plugin/plugin.json"
  if [[ ! -f "$pj" ]]; then
    add_finding ERROR 3 "$name" PLUGIN_JSON_MISSING "$name has no .claude-plugin/plugin.json"
    return 0
  fi
  local pver pdesc
  pver="$(json_field "$pj" version)"
  pdesc="$(json_field "$pj" description)"
  if [[ "$pver" != "$mver" ]]; then
    add_finding WARN 3 "$name" VERSION_MISMATCH \
      "plugin.json version ($pver) != marketplace.json ($mver) [also checked by /validate]"
  fi
  if [[ "$pdesc" != "$mdesc" ]]; then
    add_finding WARN 3 "$name" DESC_MISMATCH \
      "plugin.json description differs from marketplace.json — pj:\"$pdesc\" mp:\"$mdesc\""
  fi
}

check_site_parity() { # name dir   (layer ④, flag-only)
  local name="$1" rt st
  local site="$ROOT/site/$name"
  if [[ ! -e "$site" ]]; then
    add_finding WARN 4 "$name" SITE_PAGE_MISSING \
      "no site/$name page — run /walkthrough:document $name to generate it"
    return 0
  fi
  command -v git >/dev/null 2>&1 || return 0
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 0
  rt="$(git -C "$ROOT" log -1 --format=%ct -- "$name/README.md" 2>/dev/null || echo 0)"
  st="$(git -C "$ROOT" log -1 --format=%ct -- "site/$name" 2>/dev/null || echo 0)"
  if [[ "$rt" -gt 0 && "$st" -gt 0 && "$rt" -gt "$st" ]]; then
    add_finding WARN 4 "$name" SITE_PAGE_STALE \
      "$name/README.md was committed after site/$name — run /walkthrough:document $name to refresh"
  fi
}

# ---- report ----------------------------------------------------------------
print_report() {
  if [[ "$FORMAT" == "tsv" ]]; then
    local f
    for f in "${FINDINGS[@]:-}"; do [[ -n "$f" ]] && printf '%s\n' "$f"; done
    return 0
  fi
  printf 'doc-audit — %s\n' "$ROOT"
  printf 'ERROR:%d  WARN:%d  INFO:%d\n\n' "$ERROR_COUNT" "$WARN_COUNT" "$INFO_COUNT"
  local sev f s l p m c shown
  for sev in ERROR WARN INFO; do
    shown=0
    for f in "${FINDINGS[@]:-}"; do
      [[ -n "$f" ]] || continue
      IFS=$'\t' read -r s l p c m <<<"$f"
      [[ "$s" == "$sev" ]] || continue
      [[ $shown -eq 0 ]] && { printf '## %s\n' "$sev"; shown=1; }
      printf '  [L%s] %-22s %s%s\n' "$l" "$c" "${p:+$p: }" "$m"
    done
    [[ $shown -eq 1 ]] && printf '\n'
  done
  if [[ "${#COVERAGE[@]:-0}" -gt 0 ]]; then
    printf '## Coverage (command → documented?)\n'
    local row
    for row in "${COVERAGE[@]:-}"; do [[ -n "$row" ]] && printf '  %s\n' "$row"; done
    printf '\n'
  fi
}

# ---- main ------------------------------------------------------------------
main() {
  ROOT=""; FORMAT="pretty"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root)   ROOT="${2:?--root needs a value}"; shift 2 ;;
      --format) FORMAT="${2:?--format needs a value}"; shift 2 ;;
      -h|--help) echo "Usage: audit-docs.sh [--root DIR] [--format pretty|tsv]"; return 0 ;;
      *) echo "audit-docs: unknown arg: $1" >&2; return 2 ;;
    esac
  done
  [[ -n "$ROOT" ]] || ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null || pwd)"
  MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"
  [[ -f "$MARKETPLACE" ]] || { echo "audit-docs: no marketplace.json at $MARKETPLACE" >&2; return 2; }
  FINDINGS=(); COVERAGE=(); ERROR_COUNT=0; WARN_COUNT=0; INFO_COUNT=0
  local name src ver desc dir
  while IFS=$'\t' read -r name src ver desc; do
    dir="$ROOT/${src#./}"
    check_plugin_skills "$name" "$dir"
    check_manifest_sync "$name" "$dir" "$ver" "$desc"
    check_site_parity   "$name" "$dir"
  done < <(list_plugins)
  check_root_readme
  print_report
  [[ "$ERROR_COUNT" -eq 0 ]]
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
