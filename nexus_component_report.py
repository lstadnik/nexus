#!/usr/bin/env python3
"""Nexus Repository Manager — raport liczby komponentów per repozytorium."""

import argparse
import sys
from urllib.parse import urljoin

import requests
from requests.auth import HTTPBasicAuth


def get_repositories(base_url, auth):
    url = urljoin(base_url, "/service/rest/v1/repositories")
    resp = requests.get(url, auth=auth, timeout=30)
    resp.raise_for_status()
    return resp.json()


def count_components(base_url, auth, repo_name):
    url = urljoin(base_url, "/service/rest/v1/components")
    params = {"repository": repo_name}
    count = 0
    while True:
        resp = requests.get(url, auth=auth, params=params, timeout=60)
        resp.raise_for_status()
        data = resp.json()
        items = data.get("items", [])
        count += len(items)
        token = data.get("continuationToken")
        if not token:
            break
        params["continuationToken"] = token
    return count


def main():
    parser = argparse.ArgumentParser(description="Raport komponentów Nexus Repository Manager")
    parser.add_argument("--url", required=True, help="URL Nexusa, np. https://nexus.example.com")
    parser.add_argument("--user", required=True, help="Nazwa użytkownika")
    parser.add_argument("--password", required=True, help="Hasło")
    parser.add_argument("--format", choices=["hosted", "proxy", "group", "all"], default="all",
                        help="Filtruj po typie repozytorium (domyślnie: all)")
    args = parser.parse_args()

    base_url = args.url.rstrip("/")
    auth = HTTPBasicAuth(args.user, args.password)

    print(f"Łączenie z Nexusem: {base_url}\n")

    try:
        repos = get_repositories(base_url, auth)
    except requests.exceptions.RequestException as e:
        print(f"Błąd połączenia: {e}", file=sys.stderr)
        sys.exit(1)

    if args.format != "all":
        repos = [r for r in repos if r.get("type") == args.format]

    repos.sort(key=lambda r: r.get("name", ""))

    print(f"{'Repozytorium':<40} {'Typ':<10} {'Format':<10} {'Komponenty':>12}")
    print("-" * 75)

    total = 0
    for repo in repos:
        name = repo.get("name", "?")
        repo_type = repo.get("type", "?")
        repo_format = repo.get("format", "?")

        try:
            count = count_components(base_url, auth, name)
        except requests.exceptions.RequestException as e:
            print(f"{name:<40} {repo_type:<10} {repo_format:<10} {'BŁĄD':>12}  ({e})")
            continue

        total += count
        print(f"{name:<40} {repo_type:<10} {repo_format:<10} {count:>12,}")

    print("-" * 75)
    print(f"{'RAZEM':<40} {'':<10} {'':<10} {total:>12,}")
    print(f"\nLiczba repozytoriów: {len(repos)}")


if __name__ == "__main__":
    main()
