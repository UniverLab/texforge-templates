#!/usr/bin/env bash
#
# check-templates.sh — offline gate for texforge-templates.
#
# Validates every template in the working tree without ever running
# `texforge new` (which refreshes cached templates from the remote registry)
# and without writing to ~/.texforge. All rendering happens in a throwaway
# temp directory; previews land under the git dir (never committed).
#
# Usage:
#   check-templates.sh [--changed <git-rev>] [NAME...]
#
# Exit codes: 0 = every selected template passed, 1 = at least one failed,
#             2 = unknown template name.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
GITDIR="$(git -C "$REPO_ROOT" rev-parse --git-dir)"
if [[ "$GITDIR" != /* ]]; then GITDIR="$REPO_ROOT/$GITDIR"; fi
PREVIEW_ROOT="$GITDIR/template-previews"

err() { printf '%s\n' "$*" >&2; }

has_template() { [[ -f "$REPO_ROOT/$1/template.toml" ]]; }

# ---------------------------------------------------------------------------
# Argument parsing: [--changed <rev>] [NAME...]
# ---------------------------------------------------------------------------
CHANGED_REV=""
if [[ "${1:-}" == "--changed" ]]; then
  shift
  CHANGED_REV="${1:?missing <rev> after --changed}"
  shift
fi

TEMPLATES=()
if [[ $# -gt 0 ]]; then
  # Explicit names: exactly those templates; unknown name -> exit 2.
  for name in "$@"; do
    if ! has_template "$name"; then
      err "unknown template: $name"
      exit 2
    fi
    TEMPLATES+=("$name")
  done
elif [[ -n "$CHANGED_REV" ]]; then
  # Templates whose directory has tracked changes since <rev> or untracked files.
  if ! git -C "$REPO_ROOT" rev-parse --verify -q "$CHANGED_REV^{commit}" >/dev/null; then
    err "unknown revision: $CHANGED_REV"
    exit 2
  fi
  while IFS= read -r dir; do
    if [[ -n "$dir" ]] && has_template "$dir"; then
      TEMPLATES+=("$dir")
    fi
  done < <(
    {
      git -C "$REPO_ROOT" diff --name-only "$CHANGED_REV"
      git -C "$REPO_ROOT" ls-files --others --exclude-standard
    } | awk -F/ 'NF && $1 != "" { print $1 }' | sort -u
  )
  if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
    echo "no template changed since $CHANGED_REV"
    exit 0
  fi
else
  # No arguments: every top-level directory containing template.toml.
  while IFS= read -r toml; do
    TEMPLATES+=("$(basename "$(dirname "$toml")")")
  done < <(find "$REPO_ROOT" -mindepth 2 -maxdepth 2 -name template.toml -type f -not -path "$REPO_ROOT/.git/*" | sort)
fi

# ---------------------------------------------------------------------------
# Scratch space (removed on exit)
# ---------------------------------------------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LOGDIR="$WORK/logs"
mkdir -p "$LOGDIR"

# ---------------------------------------------------------------------------
# Helper python snippets (run via python3 -c, stdlib tomllib only)
# ---------------------------------------------------------------------------
PY_MANIFEST=$(cat <<'EOF'
import sys, re, tomllib
root, name = sys.argv[1], sys.argv[2]
try:
    t = tomllib.load(open(root + "/" + name + "/template.toml", "rb"))
except Exception as e:
    print("cannot parse template.toml: " + str(e)); raise SystemExit(1)
if t.get("id") != name:
    print("id mismatch: " + repr(t.get("id")) + " != " + repr(name)); raise SystemExit(1)
ver = str(t.get("version", ""))
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", ver):
    print("bad version: " + repr(t.get("version"))); raise SystemExit(1)
try:
    reg = tomllib.load(open(root + "/registry.toml", "rb"))
except Exception as e:
    print("cannot parse registry.toml: " + str(e)); raise SystemExit(1)
entries = [e for e in reg.get("templates", []) if e.get("nombre") == name]
if not entries:
    print("registry.toml has no [[templates]] entry with nombre = " + repr(name)); raise SystemExit(1)
if str(entries[0].get("version", "")) != ver:
    print("version mismatch: registry.toml " + repr(entries[0].get("version")) + " != template.toml " + repr(ver))
    raise SystemExit(1)
EOF
)

PY_PLACEHOLDERS=$(cat <<'EOF'
import sys, re, tomllib, pathlib
root, name = sys.argv[1], sys.argv[2]
tdir = pathlib.Path(root) / name
try:
    t = tomllib.load(open(tdir / "template.toml", "rb"))
except Exception as e:
    print("cannot parse template.toml: " + str(e)); raise SystemExit(1)
declared = {p.get("name") for p in t.get("placeholders", [])}
builtin = {"user.name", "user.email", "institution.name"}
bad = []
for p in sorted(tdir.rglob("*")):
    if not p.is_file() or p.name == "template.toml":
        continue
    try:
        text = p.read_text("utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    for m in re.finditer(r"\{\{([A-Za-z_][A-Za-z0-9_.]*)\}\}", text):
        tok = m.group(1)
        if tok not in declared and tok not in builtin and tok not in bad:
            bad.append(tok)
if bad:
    print("undeclared placeholder(s): " + ", ".join(bad)); raise SystemExit(1)
EOF
)

PY_RENDER=$(cat <<'EOF'
import sys, re, tomllib, pathlib
root, name = sys.argv[1], sys.argv[2]
dest = pathlib.Path(sys.argv[3])
try:
    t = tomllib.load(open(root + "/" + name + "/template.toml", "rb"))
except Exception as e:
    print("cannot parse template.toml: " + str(e)); raise SystemExit(1)
ph = {p.get("name"): p for p in t.get("placeholders", []) if p.get("name")}
BUILTIN = {
    "user.name": "Sample Author",
    "user.email": "author@example.org",
    "institution.name": "Sample University",
}
TOKEN = re.compile(r"\{\{([A-Za-z_][A-Za-z0-9_.]*)\}\}")

def default_of(tok):
    p = ph.get(tok)
    if p is None or "default" not in p:
        return None
    d = p["default"]
    if isinstance(d, bool):
        return "true" if d else "false"
    if not isinstance(d, str):
        return str(d)
    m = TOKEN.fullmatch(d)
    if m:
        inner = m.group(1)
        if inner == "user.name":
            return "Sample Author"
        if inner in BUILTIN:
            return BUILTIN[inner]
        return None  # default is itself an unresolvable {{...}} token
    return d

def resolve(tok):
    if tok in BUILTIN:
        return BUILTIN[tok]
    d = default_of(tok)
    if d is not None:
        return d
    if tok == "title":
        return "Sample Document"
    return "Sample " + tok

for p in sorted(dest.rglob("*")):
    if not p.is_file():
        continue
    try:
        text = p.read_text("utf-8")
    except (UnicodeDecodeError, OSError):
        continue  # binary files are copied as-is
    new = TOKEN.sub(lambda m: resolve(m.group(1)), text)
    if new != text:
        p.write_text(new, "utf-8")

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

lines = [
    "[document]",
    'title = "' + esc(resolve("title")) + '"',
    'author = "Sample Author"',
    'template = "' + name + '"',
    "",
    "[build]",
    'entry = "main.tex"',
]
if (dest / "bib" / "references.bib").is_file():
    lines.append('bibliography = "bib/references.bib"')
(dest / "project.toml").write_text("\n".join(lines) + "\n", "utf-8")
EOF
)

PY_CONTENT=$(cat <<'EOF'
import sys, re, pathlib
work, name = sys.argv[1], sys.argv[2]
dest = pathlib.Path(work) / name
FORBIDDEN = [
    "\\usepackage[utf8]{inputenc}",
    "\\lstdefinestyle",
    "\\begin{lstlisting}",
    "\\usepackage{minted}",
]
files = []
for p in sorted(dest.rglob("*")):
    if not p.is_file():
        continue
    try:
        files.append((p, p.read_text("utf-8")))
    except (UnicodeDecodeError, OSError):
        continue
for p, text in files:
    for pat in FORBIDDEN:
        if pat in text:
            print("forbidden pattern " + pat + " in " + str(p.relative_to(dest)))
            raise SystemExit(1)
if name in ("letter", "cv"):
    raise SystemExit(0)  # content requirements are skipped for letter/cv
entry = dest / "main.tex"
if not entry.is_file():
    print("main.tex not found"); raise SystemExit(1)
seen, stack = [], [entry]
while stack:
    p = stack.pop()
    if p in seen:
        continue
    seen.append(p)
    try:
        text = p.read_text("utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    for m in re.finditer(r"\\(?:input|include)\{([^}]+)\}", text):
        cand = dest / m.group(1)
        if not cand.suffix:
            cand = cand.with_suffix(".tex")
        if cand.is_file() and cand not in seen:
            stack.append(cand)
blob = ""
for p in seen:
    try:
        blob += p.read_text("utf-8") + "\n"
    except (UnicodeDecodeError, OSError):
        pass
if "\\begin{code}[lang=" not in blob:
    print("no \\begin{code}[lang=...] block in main.tex or the files it inputs")
    raise SystemExit(1)
diag = re.compile(r"\\begin\{(mermaid|graphviz|d2)\}(\[[^\]]*\])?")
if not any(m.group(2) and "style=" in m.group(2) for m in diag.finditer(blob)):
    print("no \\begin{mermaid}/\\begin{graphviz}/\\begin{d2} whose options contain style=")
    raise SystemExit(1)
EOF
)

# ---------------------------------------------------------------------------
# Step helpers
# ---------------------------------------------------------------------------
first_line() { # first non-empty line of a file (falls back to a fixed string)
  local line
  line="$(sed -n '/[^[:space:]]/{p;q;}' "$1" 2>/dev/null || true)"
  printf '%s' "${line:-no output}"
}

print_tail() { # last 40 lines of the failing command's output
  local log=$1
  echo "  --- last 40 lines of output ---"
  tail -n 40 "$log" | sed 's/^/  /'
  echo "  ---"
}

STEP_REASON=""
STEP_LOG=""

# run_step <step-label> <function> : runs the step for $T, records the failure.
run_step() {
  local step=$1 fn=$2
  STEP_REASON=""
  STEP_LOG=""
  if "$fn"; then
    return 0
  fi
  RESULT[$T]="FAIL: $step — ${STEP_REASON:-unknown error}"
  if [[ -n "$STEP_LOG" && -f "$STEP_LOG" ]]; then
    print_tail "$STEP_LOG"
  fi
  return 1
}

fail_step() { # <reason> <log>
  STEP_REASON=$1
  STEP_LOG=${2:-}
  return 1
}

# --- Step a: manifest -------------------------------------------------------
step_manifest() {
  local log="$LOGDIR/$T.manifest.log"
  if ! python3 -c "$PY_MANIFEST" "$REPO_ROOT" "$T" >"$log" 2>&1; then
    fail_step "$(first_line "$log")" "$log"; return 1
  fi
}

# --- Step b: placeholders ---------------------------------------------------
step_placeholders() {
  local log="$LOGDIR/$T.placeholders.log"
  if ! python3 -c "$PY_PLACEHOLDERS" "$REPO_ROOT" "$T" >"$log" 2>&1; then
    fail_step "$(first_line "$log")" "$log"; return 1
  fi
}

# --- Step c: render ---------------------------------------------------------
step_render() {
  local log="$LOGDIR/$T.render.log"
  local dest="$WORK/$T"
  rm -rf "$dest"
  mkdir -p "$dest"
  if ! cp -a "$REPO_ROOT/$T/." "$dest/"; then
    fail_step "cannot copy template into $dest" ""; return 1
  fi
  rm -f "$dest/template.toml"
  if ! python3 -c "$PY_RENDER" "$REPO_ROOT" "$T" "$dest" >"$log" 2>&1; then
    fail_step "$(first_line "$log")" "$log"; return 1
  fi
}

# --- Step d: texforge pipeline ---------------------------------------------
step_texforge() {
  local dest="$WORK/$T" log

  log="$LOGDIR/$T.check.log"
  if ! (cd "$dest" && texforge check) >"$log" 2>&1; then
    fail_step "texforge check: $(first_line "$log")" "$log"; return 1
  fi
  if grep -E 'WARNING|ERROR' "$log" >/dev/null; then
    local finding
    finding="$(grep -m1 -E '(WARNING|ERROR) \[' "$log" || true)"
    if [[ -z "$finding" ]]; then
      finding="$(grep -m1 -E 'WARNING|ERROR' "$log" || true)"
    fi
    fail_step "texforge check reported: $(printf '%s' "$finding" | sed 's/^[[:space:]]*//')" "$log"; return 1
  fi

  log="$LOGDIR/$T.fmt.log"
  if ! (cd "$dest" && texforge fmt --check) >"$log" 2>&1; then
    fail_step "texforge fmt --check: $(first_line "$log")" "$log"; return 1
  fi

  log="$LOGDIR/$T.build.log"
  if ! (cd "$dest" && texforge build) >"$log" 2>&1; then
    fail_step "texforge build: $(first_line "$log")" "$log"; return 1
  fi

  log="$LOGDIR/$T.pdfcheck.log"
  if ! (cd "$dest" && texforge pdf check) >"$log" 2>&1; then
    fail_step "texforge pdf check: $(first_line "$log")" "$log"; return 1
  fi
}

# --- Step e: previews + page count -----------------------------------------
step_previews() {
  local dest="$WORK/$T" log
  local dir="$PREVIEW_ROOT/$T"

  rm -rf "$dir"
  mkdir -p "$dir"

  log="$LOGDIR/$T.preview.log"
  if ! (cd "$dest" && texforge preview --scale 1.5 --out "$dir") >"$log" 2>&1; then
    fail_step "texforge preview: $(first_line "$log")" "$log"; return 1
  fi

  log="$LOGDIR/$T.pdfinfo.log"
  if ! (cd "$dest" && texforge pdf info) >"$log" 2>&1; then
    fail_step "texforge pdf info: $(first_line "$log")" "$log"; return 1
  fi
  local pages
  pages="$(sed -n 's/^pages: *//p' "$log" | head -n 1)"
  if [[ -z "$pages" ]]; then
    fail_step "texforge pdf info: no page count in output" "$log"; return 1
  fi
  PAGES[$T]="$pages"
}

# --- Step f: content rules --------------------------------------------------
step_content() {
  local log="$LOGDIR/$T.content.log"
  if ! python3 -c "$PY_CONTENT" "$WORK" "$T" >"$log" 2>&1; then
    fail_step "$(first_line "$log")" "$log"; return 1
  fi
}

# ---------------------------------------------------------------------------
# Per-template pipeline: stop at the first failure, continue with the next
# ---------------------------------------------------------------------------
declare -A RESULT
declare -A PAGES

for T in "${TEMPLATES[@]}"; do
  printf 'Checking %s ...\n' "$T"
  PAGES[$T]="-"
  RESULT[$T]="ok"

  run_step "manifest" step_manifest      || continue
  run_step "placeholders" step_placeholders || continue
  run_step "render" step_render          || continue
  run_step "texforge" step_texforge      || continue
  run_step "previews" step_previews      || continue
  run_step "content" step_content        || continue
done

# ---------------------------------------------------------------------------
# Summary table
# ---------------------------------------------------------------------------
echo
printf '%-14s  %-5s  %s\n' "template" "pages" "result"
OVERALL=0
for T in "${TEMPLATES[@]}"; do
  printf '%-14s  %-5s  %s\n' "$T" "${PAGES[$T]:--}" "${RESULT[$T]}"
  if [[ "${RESULT[$T]}" != "ok" ]]; then
    OVERALL=1
  fi
done

exit "$OVERALL"
