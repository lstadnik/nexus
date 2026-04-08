#!/usr/bin/env bash
# Nexus Repository Manager — raport liczby komponentów per repozytorium.
# Wymagania: curl, jq

set -euo pipefail

usage() {
    echo "Użycie: $0 --url <NEXUS_URL> --user <USER> --password <PASSWORD> [--format hosted|proxy|group|all]"
    exit 1
}

FORMAT="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --url)      NEXUS_URL="${2%/}"; shift 2 ;;
        --user)     USER="$2"; shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        --format)   FORMAT="$2"; shift 2 ;;
        *)          usage ;;
    esac
done

[[ -z "${NEXUS_URL:-}" || -z "${USER:-}" || -z "${PASSWORD:-}" ]] && usage

count_components() {
    local repo="$1"
    local count=0
    local token=""
    local url

    while true; do
        url="${NEXUS_URL}/service/rest/v1/components?repository=${repo}"
        [[ -n "$token" ]] && url="${url}&continuationToken=${token}"

        response=$(curl -sf -u "${USER}:${PASSWORD}" "$url") || return 1

        batch=$(echo "$response" | jq '.items | length')
        count=$((count + batch))

        token=$(echo "$response" | jq -r '.continuationToken // empty')
        [[ -z "$token" ]] && break
    done

    echo "$count"
}

echo "Łączenie z Nexusem: ${NEXUS_URL}"
echo

repos_json=$(curl -sf -u "${USER}:${PASSWORD}" "${NEXUS_URL}/service/rest/v1/repositories") || {
    echo "Błąd połączenia z Nexusem" >&2
    exit 1
}

if [[ "$FORMAT" != "all" ]]; then
    repos_json=$(echo "$repos_json" | jq --arg f "$FORMAT" '[.[] | select(.type == $f)]')
fi

repos_json=$(echo "$repos_json" | jq 'sort_by(.name)')

repo_count=$(echo "$repos_json" | jq 'length')

printf "%-40s %-10s %-10s %12s\n" "Repozytorium" "Typ" "Format" "Komponenty"
printf '%0.s-' {1..75}; echo

total=0
for i in $(seq 0 $((repo_count - 1))); do
    name=$(echo "$repos_json" | jq -r ".[$i].name")
    type=$(echo "$repos_json" | jq -r ".[$i].type")
    fmt=$(echo "$repos_json" | jq -r ".[$i].format")

    if count=$(count_components "$name"); then
        total=$((total + count))
        printf "%-40s %-10s %-10s %'12d\n" "$name" "$type" "$fmt" "$count"
    else
        printf "%-40s %-10s %-10s %12s\n" "$name" "$type" "$fmt" "BŁĄD"
    fi
done

printf '%0.s-' {1..75}; echo
printf "%-40s %-10s %-10s %'12d\n" "RAZEM" "" "" "$total"
echo
echo "Liczba repozytoriów: ${repo_count}"
