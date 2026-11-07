#!/usr/bin/env bash
# goodnight-claude: read the Claude subscription usage (5-hour session and weekly)
# and turn it into a verdict the night loop can act on.
#
#   usage.sh            print one status line, exit with the verdict code
#   usage.sh wait       block until the session window is usable again, or until
#                       GN_WAIT_MAX_MIN passes (run it in the background)
#
# Verdicts and exit codes, highest priority first:
#   stop       30  weekly >= GN_WEEK_STOP     finish nothing new, write the report, end
#   pause      20  5h     >= GN_SESSION_PAUSE  launch nothing, run `usage.sh wait`
#   wind-down  15  weekly >= GN_WEEK_WARN     finish in-flight work, launch nothing new
#   throttle   10  5h     >= GN_SESSION_SLOW  finish in-flight work, no new delegates
#   unknown     2  the endpoint failed        treat as throttle, retry in 5 minutes
#   go          0  nothing is close
#
# An unknown line carries reason=missing-jq|missing-curl|no-token|network|http-<code>|bad-body.
# Other lines end with resume_at=HH:MM, the local time 5 minutes after the session
# window resets (or none), ready for a fixed_time schedule.
#
# The endpoint is the one /usage reads. It is undocumented, so a failure must never
# be read as "go".
set -uo pipefail

WEEK_WARN="${GN_WEEK_WARN:-75}"
WEEK_STOP="${GN_WEEK_STOP:-80}"
SESSION_SLOW="${GN_SESSION_SLOW:-90}"
SESSION_PAUSE="${GN_SESSION_PAUSE:-98}"
WAIT_MAX_MIN="${GN_WAIT_MAX_MIN:-100}"
POLL_SEC="${GN_POLL_SEC:-300}"
CACHE_SEC="${GN_CACHE_SEC:-90}"

CREDS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json"
CACHE="${XDG_RUNTIME_DIR:-/tmp}/goodnight-usage-$UID.json"

fetch() {
  # Print the response body. On failure print only the reason and return 1.
  # Serve from cache when fresh, so many callers do not hammer the endpoint.
  if [[ -f "$CACHE" ]] && (( $(date +%s) - $(stat -c %Y "$CACHE") < CACHE_SEC )); then
    cat "$CACHE"; return 0
  fi
  local tool token tmp http
  for tool in jq curl; do
    command -v "$tool" >/dev/null || { echo "missing-$tool"; return 1; }
  done
  # Claude Code refreshes this token while it runs, so read it fresh on every call.
  token="$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null)"
  [[ -n "$token" ]] || { echo "no-token"; return 1; }
  tmp="$(mktemp "$CACHE.XXXXXX")" || { echo "network"; return 1; }
  http="$(curl -s -m 15 -o "$tmp" -w '%{http_code}' https://api.anthropic.com/api/oauth/usage \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20")"
  if [[ "$http" != 200 ]]; then
    rm -f "$tmp"
    if [[ -z "$http" || "$http" == 000 ]]; then echo "network"; else echo "http-$http"; fi
    return 1
  fi
  if ! jq -e '.seven_day' >/dev/null 2>&1 <"$tmp"; then
    rm -f "$tmp"; echo "bad-body"; return 1
  fi
  # Rename into place so a parallel caller never reads a half-written cache.
  mv -f "$tmp" "$CACHE"
  cat "$CACHE"
}

status() {
  local body five week five_reset week_reset reset_s resume_at verdict code
  if ! body="$(fetch)"; then
    echo "verdict=unknown reason=${body:-network}"
    return 2
  fi
  # five_hour is null when no session window is open, which means 0 % used.
  five="$(jq -r '(.five_hour.utilization // 0) | floor' <<<"$body")"
  week="$(jq -r '(.seven_day.utilization // 0) | floor' <<<"$body")"
  five_reset="$(jq -r '.five_hour.resets_at // "none"' <<<"$body")"
  week_reset="$(jq -r '.seven_day.resets_at // "none"' <<<"$body")"
  resume_at=none
  if [[ "$five_reset" != none ]] && reset_s="$(date -d "$five_reset" +%s 2>/dev/null)"; then
    resume_at="$(date -d "@$(( reset_s + 300 ))" +%H:%M)"
  fi

  if   (( week >= WEEK_STOP ));     then verdict=stop;      code=30
  elif (( five >= SESSION_PAUSE )); then verdict=pause;     code=20
  elif (( week >= WEEK_WARN ));     then verdict=wind-down; code=15
  elif (( five >= SESSION_SLOW ));  then verdict=throttle;  code=10
  else                                   verdict=go;        code=0
  fi
  echo "verdict=$verdict session=${five}% session_resets=$five_reset weekly=${week}% weekly_resets=$week_reset resume_at=$resume_at"
  return "$code"
}

wait_usable() {
  # Exit 0 as soon as the session window is no longer at pause level.
  # Exit 30 if the weekly stop is reached. Exit 20 after WAIT_MAX_MIN so the
  # caller relaunches it (background commands have a 2-hour ceiling).
  local deadline=$(( $(date +%s) + WAIT_MAX_MIN * 60 )) line code
  while :; do
    line="$(status)"; code=$?
    echo "$(date -Is) $line"
    case "$code" in
      0|10|15) return 0 ;;
      30)      return 30 ;;
    esac
    (( $(date +%s) >= deadline )) && return 20
    sleep "$POLL_SEC"
    rm -f "$CACHE"
  done
}

case "${1:-status}" in
  status) status ;;
  wait)   wait_usable ;;
  *) echo "usage: $0 [status|wait]" >&2; exit 64 ;;
esac
