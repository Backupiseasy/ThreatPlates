"""Unit tests for localization_tool.py.

Run with: python3 -m pytest Source/test_localization_tool.py -v

Each test builds an isolated fake addon tree under tmp_path rather than
touching the real repo, so these stay fast and deterministic.
"""
import os

import pytest

from localization_tool import (
    cmd_check,
    cmd_extract,
    extract_l_calls,
    lua_quote,
    parse_enus_keys,
    scan_repository,
)


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return path


# ---------------------------------------------------------------------------
# extract_l_calls: static keys, every string-literal syntax
# ---------------------------------------------------------------------------

def test_double_quoted_key_is_extracted(tmp_path):
    p = write(str(tmp_path / "Widgets" / "Foo.lua"), 'name = L["Foo"]\n')
    keys, dynamic = extract_l_calls(p)
    assert keys == ["Foo"]
    assert dynamic == []


def test_single_quoted_key_is_extracted(tmp_path):
    p = write(str(tmp_path / "Widgets" / "Foo.lua"), "name = L['Foo']\n")
    keys, dynamic = extract_l_calls(p)
    assert keys == ["Foo"]


def test_long_bracket_multiline_key_is_extracted(tmp_path):
    p = write(str(tmp_path / "Widgets" / "Foo.lua"),
              "name = L[ [=[Hello\nWorld]=] ]\n")
    keys, dynamic = extract_l_calls(p)
    assert keys == ["Hello\nWorld"]


def test_commented_out_l_call_is_not_extracted(tmp_path):
    p = write(str(tmp_path / "Widgets" / "Foo.lua"),
              '-- name = L["DeadCode"]\nlive = L["Live"]\n')
    keys, dynamic = extract_l_calls(p)
    assert keys == ["Live"]
    assert "DeadCode" not in keys


def test_bom_prefixed_file_is_parsed(tmp_path):
    # Several real files in this repo (Commands.lua, Addon.lua, ...) start
    # with a UTF-8 BOM; the lexer chokes on it unless read as utf-8-sig.
    p = str(tmp_path / "Widgets" / "Foo.lua")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8-sig") as f:
        f.write('name = L["Foo"]\n')
    keys, _ = extract_l_calls(p)
    assert keys == ["Foo"]


# ---------------------------------------------------------------------------
# extract_l_calls: dynamic (non-literal) keys are reported, not extracted as
# garbage strings - this is the regex-artifact bug the AST rewrite fixes
# (the old tool turned L["Show "..faction.." Units"] into a fake literal key
# 'Show "..faction.." Units').
# ---------------------------------------------------------------------------

def test_concat_expression_is_dynamic_not_a_fake_key(tmp_path):
    p = write(str(tmp_path / "Options.lua"),
              'name = L["Show "..faction.." Units"]\n')
    keys, dynamic = extract_l_calls(p)
    assert keys == []
    assert len(dynamic) == 1
    assert dynamic[0][0] == "Concat"


def test_variable_index_is_dynamic(tmp_path):
    p = write(str(tmp_path / "Options.lua"), "name = L[unit_type]\n")
    keys, dynamic = extract_l_calls(p)
    assert keys == []
    assert len(dynamic) == 1


# ---------------------------------------------------------------------------
# Directory walk: default-allow model (the old tool's allowlist rotted -
# Modules/ was silently never scanned; the new tool must not repeat that)
# ---------------------------------------------------------------------------

def test_new_unforeseen_directory_is_still_scanned(tmp_path):
    # A directory name the tool has never heard of before must be scanned by
    # default - only the explicit blocklist is excluded.
    write(str(tmp_path / "BrandNewFeature" / "Thing.lua"), 'x = L["FoundMe"]\n')
    static_keys, _ = scan_repository(str(tmp_path))
    assert "FoundMe" in static_keys


@pytest.mark.parametrize("blocked_dir", ["Libs", "Locales", "Source", "Test"])
def test_blocked_directories_are_skipped(tmp_path, blocked_dir):
    write(str(tmp_path / blocked_dir / "Thing.lua"), 'x = L["ShouldNotBeFound"]\n')
    static_keys, _ = scan_repository(str(tmp_path))
    assert "ShouldNotBeFound" not in static_keys


# ---------------------------------------------------------------------------
# lua_quote: the escaping bug found while validating extract's own output
# ---------------------------------------------------------------------------

def test_lua_quote_escapes_embedded_newline():
    # A raw newline must never reach the output file unescaped - a "..."
    # Lua string literal cannot contain one (unlike the [=[ ]=] source it
    # came from), so the unescaped version is invalid Lua.
    assert lua_quote("a\nb") == "a\\nb"


def test_lua_quote_escapes_quotes_and_backslashes():
    assert lua_quote('He said "hi" \\') == 'He said \\"hi\\" \\\\'


# ---------------------------------------------------------------------------
# extract end-to-end: output file must itself be valid Lua and merge the
# special-phrase-keys registry
# ---------------------------------------------------------------------------

def test_extract_output_is_valid_lua_and_includes_registry_keys(tmp_path):
    write(str(tmp_path / "Options.lua"),
          'x = L["Hello\\nWorld via escape"]\n'
          'y = L[ [=[Hello\nWorld via long-bracket]=] ]\n')
    write(str(tmp_path / "Source" / "LocalizationSpecialPhraseKeys.lua"),
          'L["FromRegistry"] = true\n')

    out_file = str(tmp_path / "out.txt")

    class Args:
        root = str(tmp_path)
        out = out_file

    assert cmd_extract(Args()) == 0

    from luaparser import ast as lua_ast
    content = open(out_file, encoding="utf-8").read()
    lua_ast.parse("local L = {}\n" + content)  # must not raise
    assert "FromRegistry" in content
    assert "Hello\\nWorld via long-bracket" in content


# ---------------------------------------------------------------------------
# check: the actual regression this tool exists to prevent
# ---------------------------------------------------------------------------

def make_enus(tmp_path, *keys):
    body = "\n".join(f'L["{k}"] = "{k}"' for k in keys)
    write(str(tmp_path / "Locales" / "enUS.lua"), body + "\n")


def test_check_fails_on_missing_key(tmp_path):
    write(str(tmp_path / "Options.lua"), 'x = L["UsedButNotTranslated"]\n')
    make_enus(tmp_path, "SomethingElse")

    class Args:
        root = str(tmp_path)

    assert cmd_check(Args()) == 1


def test_check_passes_when_every_used_key_is_translated(tmp_path):
    write(str(tmp_path / "Options.lua"), 'x = L["Foo"]\n')
    make_enus(tmp_path, "Foo")

    class Args:
        root = str(tmp_path)

    assert cmd_check(Args()) == 0


def test_check_does_not_flag_dynamic_registry_keys_as_missing(tmp_path):
    # unit_type.."s" can't be statically resolved, but the registry vouches
    # for the resulting key - check must not demand it appear literally in
    # the scanned .lua files, only in enUS.lua.
    write(str(tmp_path / "Options.lua"), 'x = L[unit_type.."s"]\n')
    write(str(tmp_path / "Source" / "LocalizationSpecialPhraseKeys.lua"),
          'L["Players"] = true\n')
    make_enus(tmp_path, "Players")

    class Args:
        root = str(tmp_path)

    assert cmd_check(Args()) == 0


def test_parse_enus_keys_handles_long_bracket_entries(tmp_path):
    p = write(str(tmp_path / "enUS.lua"),
              'L[ [=[Multi\nLine]=] ] = [=[Multi\nLine]=]\n')
    keys = parse_enus_keys(p)
    assert keys == {"Multi\nLine"}
