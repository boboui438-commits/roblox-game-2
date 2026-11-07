#!/usr/bin/env python3
"""
Tests logiques (hors Roblox) des modules partagés.

Le script concatène les modules réels (`Config`, `Util`, `EggCatalog`,
`SessionService`) dans un seul fichier Luau, avec un minimum de stubs pour les
types Roblox, puis exécute les assertions avec le binaire `luau`.

Usage :
    python3 tests/run_logic_tests.py
    LUAU_BIN=/chemin/vers/luau python3 tests/run_logic_tests.py
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

MODULES = [
    ("Config", "shared/Config.luau"),
    ("Util", "shared/Util.luau"),
    ("EggCatalog", "shared/EggCatalog.luau"),
    ("SessionService", "server/SessionService.luau"),
]

PRELUDE = """
--!nonstrict
local __mod = {}

CFrame = {
    new = function(x, y, z)
        return { X = x or 0, Y = y or 0, Z = z or 0,
                 Position = { X = x or 0, Y = y or 0, Z = z or 0 } }
    end,
}
Color3 = {
    fromHex = function(hex) return { Hex = hex } end,
    fromRGB = function(r, g, b) return { R = r, G = g, B = b } end,
}
game = {
    GetService = function(_self, _name)
        return { WaitForChild = function(_s, childName) return childName end }
    end,
}
"""


def rewrite_requires(source: str) -> str:
    source = re.sub(r"require\(script\.Parent\.([A-Za-z0-9_]+)\)", r"__mod.\1", source)
    source = re.sub(
        r'require\(Shared:WaitForChild\("([A-Za-z0-9_]+)"\)\)', r"__mod.\1", source
    )
    return source


def build_bundle() -> str:
    chunks = [PRELUDE]
    for name, relative_path in MODULES:
        with open(os.path.join(SRC, relative_path), encoding="utf-8") as handle:
            source = handle.read()
        chunks.append(f"\n-- ==== module {name} ====\n__mod.{name} = (function()\n{rewrite_requires(source)}\nend)()\n")

    with open(os.path.join(ROOT, "tests", "logic_assertions.luau"), encoding="utf-8") as handle:
        chunks.append("\n" + handle.read())

    return "".join(chunks)


def find_luau() -> str:
    candidate = os.environ.get("LUAU_BIN") or shutil.which("luau")
    if not candidate:
        sys.exit("Binaire 'luau' introuvable. Installez-le ou définissez LUAU_BIN.")
    return candidate


def main() -> int:
    bundle = build_bundle()
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as handle:
        handle.write(bundle)
        path = handle.name

    try:
        result = subprocess.run([find_luau(), path])
        return result.returncode
    finally:
        os.unlink(path)


if __name__ == "__main__":
    raise SystemExit(main())
