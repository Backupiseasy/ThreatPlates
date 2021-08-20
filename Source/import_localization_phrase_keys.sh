#!/bin/bash

# Source: https://raw.githubusercontent.com/WeakAuras/WeakAuras2/main/update_translations.sh

cf_token=

# Load secrets
if [ -f ".env" ]; then
	. ".env"
fi

[ -z "$cf_token" ] && cf_token=$CF_API_KEY

declare -A locale_files=(
  ["default"]="phrase_keys_export_file.txt"
)

tempfile=$( mktemp )
trap 'rm -f $tempfile' EXIT

do_import() {
  namespace="$1"
  file="$2"
  : > "$tempfile"

  echo -n "Importing $namespace..."
  result=$( curl -sS -0 -X POST -w "%{http_code}" -o "$tempfile" \
    -H "X-Api-Token: $CF_API_KEY" \
    -F "metadata={ language: \"enUS\", \"missing-phrase-handling\": \"DoNothing\" }" \
    -F "localizations=<$file" \
    "https://www.curseforge.com/api/projects/21217/localization/import"
  ) || exit 1
  case $result in
    200) echo "done." ;;
    *)
      echo "error! ($result)"
      [ -s "$tempfile" ] && grep -q "errorMessage" "$tempfile" | jq --raw-output '.errorMessage' "$tempfile"
      exit 1
      ;;
  esac
}

for namespace in "${!locale_files[@]}"; do
  do_import "$namespace" "${locale_files[$namespace]}"
done

exit 0
