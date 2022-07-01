#!/bin/bash

# Source: https://raw.githubusercontent.com/WeakAuras/WeakAuras2/main/update_translations.sh

cf_token=

# Load secrets
if [ -f ".release/.env" ]; then
	. ".release/.env"
fi

[ -z "$cf_token" ] && cf_token=$CF_API_KEY

declare -A locale_files=(
  ["deDE"]="deDE.lua"
  ["enUS"]="enUS.lua"
  ["esES"]="esES.lua"
  ["esMX"]="esMX.lua"
  ["zhTW"]="zhTW.lua"
  ["zhCN"]="zhCN.lua"
  # Languages below are not really maintained
  ["frFR"]="frFR.lua"
  ["koKR"]="koKR.lua"
  ["ruRU"]="ruRU.lua"
  ["itIT"]="itIT.lua"
  ["ptBR"]="ptBR.lua"
  ["ruRU"]="ruRU.lua"
)

tempfile=$( mktemp )
trap 'rm -f $tempfile' EXIT

do_export() {
  lang="$1"
  output_file="$2"

  : > "$tempfile"

  echo -n "Exporting $lang ..."
  result=$( curl -sS -0 -X GET -w "%{http_code}" -o "$output_file" \
    -H "X-Api-Token: $CF_API_KEY" \
    "https://www.curseforge.com/api/projects/21217/localization/export?lang=$lang&export-type=TableAdditions"
  ) || exit 1
  case $result in
    200) echo "done." ;;
    *)
      echo "error! ($result)"
      [ -s "$tempfile" ] && grep -q "errorMessage" "$tempfile" | jq --raw-output '.errorMessage' "$tempfile"
      exit 1
      ;;
  esac

  sed -i '1d' "$output_file"
  if [ "$lang" = "enUS" ]; then
    sed_command='1ilocal L = LibStub("AceLocale-3.0"):NewLocale("TidyPlatesThreat", "'$lang'", true, true)\nif not L then return end\n'
  else
    sed_command='1ilocal L = LibStub("AceLocale-3.0"):NewLocale("TidyPlatesThreat", "'$lang'", false)\nif not L then return end\n'
  fi
  sed -i "$sed_command" "$output_file"
}

for lang in "${!locale_files[@]}"; do
  do_export "$lang" "Locales/${locale_files[$lang]}"
done

exit 0
