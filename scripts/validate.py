#!/usr/bin/env python3
"""Validate the model-router skill and every adapter agent file.

Checks SKILL.md against the Agent Skills spec and each adapters/*/agents/*
file for name, description and model. Needs Python 3.11+ and pyyaml.
"""
import re
import sys
import tomllib
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
SKILL_DIR = ROOT / "skills" / "model-router"
ROLES = ("scout", "builder", "reviewer", "architect")
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

results = []  # (status, subject, detail)


def record(ok, subject, detail=""):
    results.append(("PASS" if ok else "FAIL", subject, detail))


def frontmatter(path):
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", text, re.S)
    if not m:
        raise ValueError("no YAML frontmatter")
    data = yaml.safe_load(m.group(1))
    if not isinstance(data, dict):
        raise ValueError("frontmatter is not a mapping")
    return data


def check_skill():
    path = SKILL_DIR / "SKILL.md"
    subj = "skill"
    if not path.is_file():
        record(False, subj, "SKILL.md missing")
        return
    try:
        fm = frontmatter(path)
    except Exception as e:  # noqa: BLE001
        record(False, subj, f"cannot parse frontmatter: {e}")
        return
    name = fm.get("name")
    ok = isinstance(name, str) and name == SKILL_DIR.name
    record(ok, f"{subj}: name matches folder", f"name={name!r}")
    ok = isinstance(name, str) and len(name) <= 64 and bool(NAME_RE.match(name))
    record(ok, f"{subj}: name lowercase-hyphen, <=64", "")
    desc = fm.get("description")
    ok = isinstance(desc, str) and 1 <= len(desc) <= 300
    record(ok, f"{subj}: description 1-300 chars",
           f"{len(desc)} chars" if isinstance(desc, str) else "missing")
    if "compatibility" in fm:
        c = fm["compatibility"]
        ok = isinstance(c, str) and 1 <= len(c) <= 500
        record(ok, f"{subj}: compatibility <=500 chars",
               f"{len(c)} chars" if isinstance(c, str) else "not a string")
    if "metadata" in fm:
        md = fm["metadata"]
        ok = isinstance(md, dict) and all(
            isinstance(k, str) and isinstance(v, str) for k, v in md.items())
        record(ok, f"{subj}: metadata values are strings", "")
    lines = len(path.read_text(encoding="utf-8").splitlines())
    record(lines <= 500, f"{subj}: SKILL.md <=500 lines", f"{lines} lines")


def agent_base(path):
    n = path.name
    for suffix in (".agent.md", ".md", ".toml"):
        if n.endswith(suffix):
            return n[: -len(suffix)]
    return path.stem


def check_agent(path):
    subj = str(path.relative_to(ROOT))
    try:
        if path.suffix == ".toml":
            data = tomllib.loads(path.read_text(encoding="utf-8"))
        else:
            data = frontmatter(path)
    except Exception as e:  # noqa: BLE001
        record(False, subj, f"parse error: {e}")
        return
    problems = []
    if data.get("name") != agent_base(path):
        problems.append(f"name {data.get('name')!r} != {agent_base(path)!r}")
    desc = data.get("description")
    if isinstance(desc, str) and len(desc) > 300:
        problems.append(f"description {len(desc)} chars > 300")
    for key in ("description", "model"):
        v = data.get(key)
        if v is None or v == "" or v == []:
            problems.append(f"{key} missing")
    record(not problems, subj, "; ".join(problems))


def check_platform_files():
    ref = SKILL_DIR / "references" / "platforms" / "claude-app.md"
    record(ref.is_file(), "platform reference: claude-app.md",
           "present" if ref.is_file() else "missing")


def check_adapters():
    base = ROOT / "adapters"
    if not base.is_dir():
        record(False, "adapters", "adapters/ missing")
        return
    folders = sorted(p for p in base.iterdir() if p.is_dir())
    if not folders:
        record(False, "adapters", "no adapter folders")
    for folder in folders:
        agents = folder / "agents"
        files = sorted(f for f in agents.glob("*") if f.is_file()) if agents.is_dir() else []
        bases = {agent_base(f) for f in files}
        missing = [r for r in ROLES if f"router-{r}" not in bases]
        record(not missing, f"adapter {folder.name}: scout/builder/reviewer/architect",
               ("missing " + ", ".join(missing)) if missing else f"{len(files)} agents")
        for f in files:
            check_agent(f)


def main():
    check_skill()
    check_platform_files()
    check_adapters()
    width = max(len(r[1]) for r in results)
    print(f"{'STATUS':<7}{'CHECK':<{width + 2}}DETAIL")
    for status, subj, detail in results:
        print(f"{status:<7}{subj:<{width + 2}}{detail}")
    failed = sum(1 for r in results if r[0] == "FAIL")
    print(f"\n{len(results) - failed} passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
