#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."

echo "Fetching categories from crates.io..."
PAGE1=$(curl -s "https://crates.io/api/v1/categories?page=1")
TOTAL=$(echo "$PAGE1" | jq -r '.meta.total')
PER_PAGE=10
PAGES=$(( (TOTAL + PER_PAGE - 1) / PER_PAGE ))

echo "Found $TOTAL categories across $PAGES pages"

TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# Build a valid YAML file with choices mapping
echo "choices:" > "$TEMP_FILE"

# Fetch all pages and format as YAML mapping entries (not list entries)
# Copier multiselect requires mapping format: "Label: value" not "- Label: value"
for ((page=1; page<=PAGES; page++)); do
    echo "Fetching page $page of $PAGES..."
    curl -s "https://crates.io/api/v1/categories?page=$page" | \
        jq -r '.categories[] | "  " + .category + ": " + .slug' >> "$TEMP_FILE"
done

# Sort the entries (skip header line, sort, recombine)
head -1 "$TEMP_FILE" > "${TEMP_FILE}.sorted"
tail -n +2 "$TEMP_FILE" | sort -u >> "${TEMP_FILE}.sorted"
mv "${TEMP_FILE}.sorted" "$TEMP_FILE"

# Inject into copier.yaml
cd "$PROJECT_ROOT"
yq -i ".categories.choices = load(\"$TEMP_FILE\").choices" copier.yaml

echo "Done! Updated $(tail -n +2 "$TEMP_FILE" | wc -l | tr -d ' ') categories in copier.yaml"
