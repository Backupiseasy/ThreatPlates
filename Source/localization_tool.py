#!/usr/bin/env python3
"""Consolidated localization tooling for TidyPlates_ThreatPlates.

Replaces:
  - Source/ExtractPhraseKeysForLocalization.lua (regex-based extraction)
  - Source/import_localization_phrase_keys.sh (CurseForge upload)
  - the inline bash extract/pull-back logic in
    .github/workflows/sync_localization_translations.yml

AST-based (via the `luaparser` package) instead of regex-based, so it
correctly distinguishes a literal L["key"] from a dynamic L[expr] (e.g.
L[unit_type.."s"]), handles every Lua string-literal syntax (single quotes,
long-bracket multi-line strings) and never sees commented-out code (comments
are not part of the AST at all).

Subcommands:
  extract  Scan Lua source for L["..."] keys, write phrase_keys_export_file.txt
  check    Diff extracted keys against Locales/enUS.lua, fail on missing keys;
           also reports per-locale translation completeness (informational)
  upload   POST phrase_keys_export_file.txt to CurseForge as new enUS phrases
  pull     Download current translations for each Locales.xml-enabled locale
           and rewrite Locales/<locale>.lua
"""
import argparse
import os
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

from luaparser import ast

CURSEFORGE_PROJECT_ID = 21217
CURSEFORGE_BASE = "https://legacy.curseforge.com/api/projects"
BLOCKED_DIRS = {"Libs", "Locales", "Source", "Test", ".git", ".github", ".idea", ".release"}
DEFAULT_EXPORT_FILE = "phrase_keys_export_file.txt"


# ---------------------------------------------------------------------------
# Lua source scanning
# ---------------------------------------------------------------------------

def iter_lua_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in BLOCKED_DIRS]
        for fn in filenames:
            if fn.endswith(".lua"):
                yield os.path.join(dirpath, fn)


def _decode(s):
    return s.decode("utf-8", errors="replace") if isinstance(s, bytes) else s


def lua_quote(s):
    """Escape a string for use inside a double-quoted Lua string literal.
    Needed because extracted keys can come from long-bracket [=[...]=] source
    strings, which allow raw newlines that a "..." literal does not."""
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
    return s


def _line_of(node):
    # node.line is broken on some node types in luaparser (raises
    # AttributeError instead of returning None); first_token.line is reliable.
    tok = getattr(node, "first_token", None)
    return tok.line if tok is not None else None


def parse_lua_file(path):
    # utf-8-sig: several files in this repo (Commands.lua, Addon.lua, Media.lua,
    # Styles/init.lua, Styles/basicThemes.lua, Locales/enGB.lua) start with a
    # UTF-8 BOM that luaparser's lexer otherwise fails to tokenize.
    with open(path, encoding="utf-8-sig") as f:
        return ast.parse(f.read())


def find_l_index_nodes(tree):
    for node in ast.walk(tree):
        if isinstance(node, ast.Index) and getattr(node.value, "id", None) == "L":
            yield node


def extract_l_calls(path):
    """Return (static_keys, dynamic_sites) found in a single Lua file.

    static_keys: list[str]
    dynamic_sites: list[(expr_type_name, line)]
    """
    static_keys = []
    dynamic_sites = []
    tree = parse_lua_file(path)
    for node in find_l_index_nodes(tree):
        idx = node.idx
        if isinstance(idx, ast.String):
            static_keys.append(_decode(idx.s))
        else:
            dynamic_sites.append((type(idx).__name__, _line_of(node)))
    return static_keys, dynamic_sites


def extract_registry_keys(registry_path):
    """Source/LocalizationSpecialPhraseKeys.lua is just L["key"] = <anything>
    assignments documenting dynamically-constructed keys; parse it the same way."""
    keys, _ = extract_l_calls(registry_path)
    return keys


def scan_repository(root):
    """Returns (static_keys, dynamic_sites).

    static_keys: dict[str, list[str]] - key -> file paths where it was seen
    dynamic_sites: list[(expr_type_name, file, line)]
    """
    static_keys = {}
    dynamic_sites = []
    for path in iter_lua_files(root):
        keys, sites = extract_l_calls(path)
        for k in keys:
            static_keys.setdefault(k, []).append(path)
        for expr_type, line in sites:
            dynamic_sites.append((expr_type, path, line))
    return static_keys, dynamic_sites


def registry_path_for(root):
    return os.path.join(root, "Source", "LocalizationSpecialPhraseKeys.lua")


# ---------------------------------------------------------------------------
# extract
# ---------------------------------------------------------------------------

def cmd_extract(args):
    static_keys, dynamic_sites = scan_repository(args.root)

    reg_path = registry_path_for(args.root)
    registry_keys = extract_registry_keys(reg_path) if os.path.exists(reg_path) else []

    if dynamic_sites:
        print(f"Found {len(dynamic_sites)} dynamic L[...] usage site(s) "
              f"(not a literal string, can't be auto-extracted):", file=sys.stderr)
        for expr_type, path, line in dynamic_sites:
            print(f"  {path}:{line}: L[<{expr_type}>]", file=sys.stderr)
        print(f"Make sure each is covered by an entry in {reg_path}.", file=sys.stderr)

    combined = sorted(set(static_keys) | set(registry_keys))

    with open(args.out, "w", encoding="utf-8") as f:
        for key in combined:
            f.write(f'L["{lua_quote(key)}"] = true\n')

    print(f"Wrote {len(combined)} phrase keys to {args.out}")
    return 0


# ---------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------

def parse_locale_keys(locale_path):
    """Every L["key"] = ... assignment target in a Locales/<locale>.lua file.
    Works for any locale, not just enUS - the AceLocale file format is the same."""
    keys = set()
    tree = parse_lua_file(locale_path)
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign):
            continue
        for target in node.targets:
            if isinstance(target, ast.Index) and getattr(target.value, "id", None) == "L":
                if isinstance(target.idx, ast.String):
                    keys.add(_decode(target.idx.s))
    return keys


def locale_translation_stats(root, enus_keys):
    """Per active (non-enUS, non-commented-out in Locales.xml) locale: how many of the
    current enUS keys have a translated entry. Denominator is always len(enus_keys) - a
    locale file can contain stale entries for keys no longer in enUS, which must not
    inflate its completion percentage."""
    locales_xml = os.path.join(root, "Locales", "Locales.xml")
    if not os.path.exists(locales_xml):
        return []
    locales = [l for l in enabled_locales(locales_xml) if l != "enUS"]
    stats = []
    for locale in locales:
        locale_path = os.path.join(root, "Locales", f"{locale}.lua")
        locale_keys = parse_locale_keys(locale_path)
        translated = len(enus_keys & locale_keys)
        total = len(enus_keys)
        missing = total - translated
        pct = (translated / total * 100) if total else 100.0
        stats.append((locale, translated, total, missing, pct))
    return stats


def cmd_check(args):
    static_keys, _ = scan_repository(args.root)
    reg_path = registry_path_for(args.root)
    registry_keys = set(extract_registry_keys(reg_path)) if os.path.exists(reg_path) else set()

    used_keys = set(static_keys) | registry_keys
    enus_keys = parse_locale_keys(os.path.join(args.root, "Locales", "enUS.lua"))

    missing = sorted(used_keys - enus_keys)
    unused = sorted(enus_keys - used_keys)

    if unused:
        print(f"INFO: {len(unused)} key(s) in enUS.lua not found in scanned code/registry "
              f"(may be used dynamically - not necessarily dead, verify before deleting):")
        for k in unused[:50]:
            print(f"  {k!r}")
        if len(unused) > 50:
            print(f"  ... and {len(unused) - 50} more")
        print()

    rc = 0
    if missing:
        print(f"ERROR: {len(missing)} key(s) used in code but missing from Locales/enUS.lua:")
        for k in missing:
            files = ", ".join(static_keys.get(k, ["(registry)"])[:3])
            print(f"  {k!r}  (used in: {files})")
        rc = 1
    else:
        print("OK: every statically-extracted key has a Locales/enUS.lua entry.")

    stats = locale_translation_stats(args.root, enus_keys)
    if stats:
        print()
        print(f"Translation status (of {len(enus_keys)} enUS keys):")
        width = max(len(s[0]) for s in stats)
        for locale, translated, total, miss, pct in stats:
            print(f"  {locale.ljust(width)} : {translated:4d}/{total} ({pct:5.1f}%)  {miss} missing")

    return rc


# ---------------------------------------------------------------------------
# upload
# ---------------------------------------------------------------------------

def cmd_upload(args):
    with open(args.file, "rb") as f:
        body = f.read()

    boundary = "----localizationtoolboundary"
    metadata = '{ language: "enUS", "missing-phrase-handling": "DoNothing" }'

    parts = [
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="metadata"\r\n\r\n'
        f"{metadata}\r\n".encode(),
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="localizations"; '
        f'filename="{os.path.basename(args.file)}"\r\n\r\n'.encode(),
        body,
        f"\r\n--{boundary}--\r\n".encode(),
    ]
    data = b"".join(parts)

    url = f"{CURSEFORGE_BASE}/{CURSEFORGE_PROJECT_ID}/localization/import"
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("X-Api-Token", args.token)
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")

    try:
        with urllib.request.urlopen(req) as resp:
            print(f"Upload OK: HTTP {resp.status}")
            return 0
    except urllib.error.HTTPError as e:
        print(f"Upload FAILED: HTTP {e.code}: {e.read().decode(errors='replace')}", file=sys.stderr)
        return 1


# ---------------------------------------------------------------------------
# pull
# ---------------------------------------------------------------------------

def enabled_locales(locales_xml_path):
    """Locales actually <Script>-loaded in Locales.xml. ElementTree does not
    expose XML comments as elements, so commented-out <Script> tags (disabled
    on purpose, e.g. for translation quality) are automatically excluded.

    Locales.xml declares a default xmlns (http://www.blizzard.com/wow/ui/) on
    its root, so every <Script> element is namespaced
    ({http://www.blizzard.com/wow/ui/}Script) - match by local name (ignoring
    any namespace) rather than an exact tag, otherwise iter("Script") silently
    matches nothing against the real file."""
    tree = ET.parse(locales_xml_path)
    locales = []
    for el in tree.getroot().iter():
        if el.tag.rsplit("}", 1)[-1] != "Script":
            continue
        fn = el.get("file", "")
        if fn.endswith(".lua"):
            locales.append(fn[:-4])
    return locales


def existing_header(locale_path):
    """Preserve a locale's exact NewLocale(...) header instead of guessing one
    - flags differ per locale (e.g. enUS has extra `true, true` arguments)."""
    if not os.path.exists(locale_path):
        return None
    with open(locale_path, encoding="utf-8-sig") as f:
        lines = f.readlines()
    return "".join(lines[:2]) if len(lines) >= 2 else None


def cmd_pull(args):
    locales_xml = os.path.join(args.root, "Locales", "Locales.xml")
    locales = [l for l in enabled_locales(locales_xml) if l != "enUS"]
    if args.locale:
        locales = [l for l in locales if l in args.locale]

    if not locales:
        print("No locales to pull (enUS excluded, none enabled, or --locale filtered all out).")
        return 0

    failures = []
    for locale in locales:
        print(f"Fetching {locale}...")
        url = f"{CURSEFORGE_BASE}/{CURSEFORGE_PROJECT_ID}/localization/export?lang={locale}"
        req = urllib.request.Request(url)
        req.add_header("X-Api-Token", args.token)
        try:
            with urllib.request.urlopen(req) as resp:
                body = resp.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            print(f"  ERROR fetching {locale}: HTTP {e.code}", file=sys.stderr)
            failures.append(locale)
            continue

        stripped = body.strip()
        head = stripped[:200]
        if stripped.startswith('{"error') or "<!DOCTYPE" in head or "<html" in head.lower():
            print(f"  ERROR: unexpected response for {locale}: {head}", file=sys.stderr)
            failures.append(locale)
            continue

        locale_path = os.path.join(args.root, "Locales", f"{locale}.lua")
        header = existing_header(locale_path) or (
            f'local L = LibStub("AceLocale-3.0"):NewLocale("TidyPlatesThreat", "{locale}", false)\n'
            f"if not L then return end\n"
        )
        # CurseForge prefixes the export with a defensive "L = L or {}" line
        # meant for inline @localization@ substitution into an existing file;
        # drop it, we already declare our own local L in the header above.
        body_lines = [ln for ln in body.splitlines() if ln.strip() != "L = L or {}"]

        with open(locale_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(header)
            f.write("\n")
            f.write("\n".join(body_lines))
            f.write("\n")

        try:
            parse_lua_file(locale_path)
        except Exception as e:
            print(f"  ERROR: generated {locale_path} does not parse: {e}", file=sys.stderr)
            failures.append(locale)

    if failures:
        print(f"Failed locales: {', '.join(failures)}", file=sys.stderr)
        return 1
    print(f"Updated {len(locales)} locale file(s).")
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser():
    parser = argparse.ArgumentParser(description=__doc__,
                                      formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p_extract = sub.add_parser("extract", help="Scan Lua files for L[...] keys")
    p_extract.add_argument("--root", default=".")
    p_extract.add_argument("--out", default=DEFAULT_EXPORT_FILE)
    p_extract.set_defaults(func=cmd_extract)

    p_check = sub.add_parser("check", help="Fail if code uses keys missing from enUS.lua; "
                                            "also reports per-locale translation completeness")
    p_check.add_argument("--root", default=".")
    p_check.set_defaults(func=cmd_check)

    p_upload = sub.add_parser("upload", help="Upload phrase keys to CurseForge")
    p_upload.add_argument("--file", default=DEFAULT_EXPORT_FILE)
    p_upload.add_argument("--token", required=True)
    p_upload.set_defaults(func=cmd_upload)

    p_pull = sub.add_parser("pull", help="Pull translations from CurseForge into Locales/*.lua")
    p_pull.add_argument("--root", default=".")
    p_pull.add_argument("--token", required=True)
    p_pull.add_argument("--locale", action="append", help="Limit to specific locale(s); repeatable")
    p_pull.set_defaults(func=cmd_pull)

    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    return args.func(args) or 0


if __name__ == "__main__":
    sys.exit(main())
