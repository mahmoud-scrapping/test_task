#!/usr/bin/env bash

set -Eeuo pipefail

: "${POST_URL:?}"
: "${POST_DATA:?}"
: "${READY_MARKER:?}"
: "${MATCH_MARKER:?}"
MATCH_REGEX="${MATCH_REGEX:-}"

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36"
ORIGIN=$(printf '%s' "${POST_URL}" | sed -E 's#^(https?://[^/]+).*#\1#')

rm -f data.txt out.html

CODE=$(
curl \
    --silent \
    --show-error \
    --location \
    --retry 5 \
    --retry-delay 3 \
    --retry-connrefused \
    --ipv4 \
    --connect-timeout 10 \
    --max-time 120 \
    --cookie "AspxAutoDetectCookieSupport=1" \
    --cookie-jar data.txt \
    --output out.html \
    --write-out "%{http_code}" \
    "${POST_URL}" \
    -A "${UA}" \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
    -H "Accept-Language: en-US,en;q=0.9" \
    -H "Origin: ${ORIGIN}" \
    -H "Referer: ${ORIGIN}/" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data "${POST_DATA}"
)

echo "status ${CODE}"

if [[ "${CODE}" != "200" ]]; then
    { echo "FOUND=false"; echo "STATUS=status ${CODE}"; } >> "$GITHUB_ENV"
    exit 1
fi

if ! grep -qiF "${READY_MARKER}" out.html; then
    { echo "FOUND=false"; echo "STATUS=unexpected response"; } >> "$GITHUB_ENV"
    echo "unexpected response"
    exit 1
fi

if grep -qF "${MATCH_MARKER}" out.html; then
    N=$(grep -cF "${MATCH_MARKER}" out.html)
    ITEMS=""
    if [[ -n "${MATCH_REGEX}" ]]; then
        ITEMS=$(grep -oP "${MATCH_REGEX}" out.html | paste -sd $'\n' - || true)
    fi
    {
        echo "AVAILABLE_TIMES<<EOF"
        echo "${ITEMS}"
        echo "EOF"
        echo "FOUND=true"
        echo "STATUS=${N} match(es)."
    } >> "$GITHUB_ENV"
    echo "match ${N}"
    exit 0
fi

{ echo "FOUND=false"; echo "STATUS=no match."; } >> "$GITHUB_ENV"
echo "no match"
exit 0
