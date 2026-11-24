#!/usr/bin/env bash
#
# check-report-languages.sh — render check for report template languages.
#
# Builds the report template for each of the six supported languages with
# empty subtitle, advisor, faculty, city and verifies that:
# (a) no English default strings appear in the five non-English renders
# (b) each language's own default strings appear
# (c) Spanish shows "Índice de tablas", "Tabla", "Anexo" (not "Índice de cuadros", "Apéndice", "Cuadro")
# (d) English render shows English defaults and "Appendix"
# Also tests Spanish with explicit values for all four placeholders.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/report"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

languages=(english spanish french german italian portuguese)

# English defaults that should NOT appear in non-English renders
# Cover defaults (exact matches, unique strings)
EN_COVER_DEFAULTS=(
  "A Structured Academic Report"
  "Advisor Name"
  "Faculty of Engineering"
  "City, Country"
  "Author:"
  "Advisor:"
)

# English structural labels (patterns that match structural context)
EN_STRUCTURAL_PATTERNS=(
  "^List of Tables$"
  "Table [0-9]+\\.[0-9]+:"
  "^Appendix [A-Z]$"
)

# Language-specific expected cover strings (as they appear in PDF text)
declare -A LANG_SUBTITLE=(
  [english]="A Structured Academic Report"
  [spanish]="Un informe académico estructurado"
  [french]="Un rapport universitaire structuré"
  [german]="Ein strukturierter Studienbericht"
  [italian]="Una relazione accademica strutturata"
  [portuguese]="Um relatório acadêmico estruturado"
)

declare -A LANG_ADVISOR=(
  [english]="Advisor Name"
  [spanish]="Nombre del director"
  [french]="Nom du directeur"
  [german]="Name der Betreuung"
  [italian]="Nome del relatore"
  [portuguese]="Nome do orientador"
)

declare -A LANG_FACULTY=(
  [english]="Faculty of Engineering"
  [spanish]="Facultad de Ingeniería"
  [french]="Faculté d.ingénierie"   # dot matches any apostrophe variant
  [german]="Fakultät für Ingenieurwissenschaften"
  [italian]="Facoltà di Ingegneria"
  [portuguese]="Faculdade de Engenharia"
)

declare -A LANG_CITY=(
  [english]="City, Country"
  [spanish]="Ciudad, País"
  [french]="Ville, Pays"
  [german]="Stadt, Land"
  [italian]="Città, Paese"
  [portuguese]="Cidade, País"
)

# Author/Advisor labels as they appear in PDF (may have space before colon)
declare -A LANG_AUTHOR_LABEL=(
  [english]="Author:"
  [spanish]="Autor:"
  [french]="Auteur :"
  [german]="Autor:"
  [italian]="Autore:"
  [portuguese]="Autor:"
)

declare -A LANG_ADVISOR_LABEL=(
  [english]="Advisor:"
  [spanish]="Director:"
  [french]="Directeur :"
  [german]="Betreuung:"
  [italian]="Relatore:"
  [portuguese]="Orientador:"
)

# Structural label patterns per language (as they appear in PDF)
declare -A LANG_LIST_TABLES_PATTERN=(
  [english]="^List of Tables$"
  [spanish]="^Índice de tablas$"
  [french]="^Liste des tableaux$"
  [german]="^Tabellenverzeichnis$"
  [italian]="^Elenco delle tabelle$"
  [portuguese]="^Lista de Tabelas$"
)

declare -A LANG_TABLE_PATTERN=(
  [english]="Table [0-9]+\\.[0-9]+:"
  [spanish]="Tabla [0-9]+\\.[0-9]+:"
  # babel-french's own \tablename is "Table" (same spelling as English),
  # rendered here with an en-dash separator ("Table 3.1 – ...").
  [french]="Table [0-9]+\\.[0-9]+"
  [german]="Tabelle [0-9]+\\.[0-9]+:"
  [italian]="Tabella [0-9]+\\.[0-9]+:"
  [portuguese]="Tabela [0-9]+\\.[0-9]+:"
)

declare -A LANG_APPENDIX_PATTERN=(
  [english]="^Appendix [A-Z]$"
  [spanish]="^Anexo [A-Z]$"
  [french]="^Annexe [A-Z]$"
  [german]="^Anhang [A-Z]$"
  [italian]="^Appendice [A-Z]$"
  [portuguese]="^Apêndice [A-Z]$"
)

# Spanish-specific forbidden patterns
SPANISH_FORBIDDEN_PATTERNS=(
  "^Índice de cuadros$"
  "^Apéndice [A-Z]$"
  "Cuadro [0-9]+\\.[0-9]+:"
)

# Python script for placeholder substitution
PY_SUBSTITUTE=$(cat <<'PYEOF'
import sys, pathlib
dir_path = pathlib.Path(sys.argv[1])
lang = sys.argv[2]
subtitle = sys.argv[3]
advisor = sys.argv[4]
faculty = sys.argv[5]
city = sys.argv[6]

replacements = {
    "{{language}}": lang,
    "{{subtitle}}": subtitle,
    "{{advisor}}": advisor,
    "{{faculty}}": faculty,
    "{{city}}": city,
    "{{title}}": "Sample Report",
    "{{author}}": "Sample Author",
    "{{institution}}": "Sample University",
    "{{date}}": "\\today",
}

for tex_file in dir_path.rglob("*.tex"):
    text = tex_file.read_text("utf-8")
    for k, v in replacements.items():
        text = text.replace(k, v)
    tex_file.write_text(text, "utf-8")
PYEOF
)

# Function to substitute placeholders in a directory
substitute_placeholders() {
  local dir=$1
  local lang=$2
  local subtitle=$3
  local advisor=$4
  local faculty=$5
  local city=$6

  python3 -c "$PY_SUBSTITUTE" "$dir" "$lang" "$subtitle" "$advisor" "$faculty" "$city"
}

# Function to build and extract text for a language
test_language() {
  local lang=$1
  local project_dir="$WORKDIR/test-$lang"
  mkdir -p "$project_dir"

  echo "=== Testing $lang ==="

  cp -r "$TEMPLATE_DIR"/* "$project_dir/"
  cd "$project_dir"
  rm -f template.toml

  substitute_placeholders "$project_dir" "$lang" "" "" "" ""

  cat > project.toml <<EOF
[document]
title = "Sample Report"
author = "Sample Author"
template = "report"

[build]
entry = "main.tex"
bibliography = "bib/references.bib"
EOF

  if ! texforge check >/dev/null 2>&1; then
    echo "FAIL: texforge check failed for $lang"
    return 1
  fi

  if ! texforge fmt --check >/dev/null 2>&1; then
    echo "FAIL: texforge fmt --check failed for $lang"
    return 1
  fi

  if ! texforge build >/dev/null 2>&1; then
    echo "FAIL: texforge build failed for $lang"
    return 1
  fi

  local pdf_text
  pdf_text="$(texforge pdf text 2>/dev/null | head -500)"

  # Check (a) no English cover defaults in non-English renders
  if [[ "$lang" != "english" ]]; then
    for forbidden in "${EN_COVER_DEFAULTS[@]}"; do
      if echo "$pdf_text" | grep -q "$forbidden"; then
        echo "FAIL: English cover default '$forbidden' found in $lang render"
        return 1
      fi
    done
    for pattern in "${EN_STRUCTURAL_PATTERNS[@]}"; do
      if echo "$pdf_text" | grep -Eq "$pattern"; then
        echo "FAIL: English structural pattern '$pattern' found in $lang render"
        return 1
      fi
    done
  fi

# Check (b) language's own cover strings appear (flexible matching for typographic variants)
  local expected_cover=(
    "${LANG_SUBTITLE[$lang]}"
    "${LANG_ADVISOR[$lang]}"
    "${LANG_FACULTY[$lang]}"
    "${LANG_CITY[$lang]}"
  )

  for exp in "${expected_cover[@]}"; do
    # Use flexible matching for apostrophes (ASCII ' and typographic ') and other variants
    local flex_exp="${exp//\'/[\'\\'\\']}"  # match ASCII and typographic apostrophe
    if ! echo "$pdf_text" | grep -q "$flex_exp"; then
      echo "FAIL: Expected cover string '$exp' not found in $lang render"
      return 1
    fi
  done

  # Author/Advisor labels (flexible colon spacing)
  local author_label="${LANG_AUTHOR_LABEL[$lang]}"
  local advisor_label="${LANG_ADVISOR_LABEL[$lang]}"
  local flex_author="${author_label//:/:}"  # exact match for now
  local flex_advisor="${advisor_label//:/:}"
  if ! echo "$pdf_text" | grep -q "$flex_author"; then
    echo "FAIL: Expected author label '$author_label' not found in $lang render"
    return 1
  fi
  if ! echo "$pdf_text" | grep -q "$flex_advisor"; then
    echo "FAIL: Expected advisor label '$advisor_label' not found in $lang render"
    return 1
  fi

  # Check (b) structural labels
  if ! echo "$pdf_text" | grep -Eq "${LANG_LIST_TABLES_PATTERN[$lang]}"; then
    echo "FAIL: Expected list of tables heading '${LANG_LIST_TABLES_PATTERN[$lang]}' not found in $lang render"
    return 1
  fi
  if ! echo "$pdf_text" | grep -Eq "${LANG_TABLE_PATTERN[$lang]}"; then
    echo "FAIL: Expected table caption pattern '${LANG_TABLE_PATTERN[$lang]}' not found in $lang render"
    return 1
  fi
  if ! echo "$pdf_text" | grep -Eq "${LANG_APPENDIX_PATTERN[$lang]}"; then
    echo "FAIL: Expected appendix heading pattern '${LANG_APPENDIX_PATTERN[$lang]}' not found in $lang render"
    return 1
  fi

  # Check (c) Spanish forbidden patterns
  if [[ "$lang" == "spanish" ]]; then
    for pattern in "${SPANISH_FORBIDDEN_PATTERNS[@]}"; do
      if echo "$pdf_text" | grep -Eq "$pattern"; then
        echo "FAIL: Spanish forbidden pattern '$pattern' found in $lang render"
        return 1
      fi
    done
  fi

  # Check (d) English structural labels
  if [[ "$lang" == "english" ]]; then
    if ! echo "$pdf_text" | grep -Eq "^Appendix [A-Z]$"; then
      echo "FAIL: 'Appendix A' heading not found in english render"
      return 1
    fi
    if ! echo "$pdf_text" | grep -Eq "^List of Tables$"; then
      echo "FAIL: 'List of Tables' heading not found in english render"
      return 1
    fi
    if ! echo "$pdf_text" | grep -Eq "Table [0-9]+\\.[0-9]+:"; then
      echo "FAIL: 'Table X.Y:' caption not found in english render"
      return 1
    fi
  fi

  echo "PASS: $lang"
  return 0
}

# Function to test Spanish with explicit values
test_spanish_explicit() {
  local project_dir="$WORKDIR/test-spanish-explicit"
  mkdir -p "$project_dir"

  echo "=== Testing Spanish with explicit values ==="

  cp -r "$TEMPLATE_DIR"/* "$project_dir/"
  cd "$project_dir"
  rm -f template.toml

  substitute_placeholders "$project_dir" "spanish" \
    "Subtítulo Explícito" \
    "Director Explícito" \
    "Facultad Explícita" \
    "Ciudad Explícita, País Explícito"

  cat > project.toml <<EOF
[document]
title = "Informe de Prueba"
author = "Autor de Prueba"
template = "report"

[build]
entry = "main.tex"
bibliography = "bib/references.bib"
EOF

  if ! texforge check >/dev/null 2>&1; then
    echo "FAIL: texforge check failed for Spanish explicit"
    return 1
  fi

  if ! texforge fmt --check >/dev/null 2>&1; then
    echo "FAIL: texforge fmt --check failed for Spanish explicit"
    return 1
  fi

  if ! texforge build >/dev/null 2>&1; then
    echo "FAIL: texforge build failed for Spanish explicit"
    return 1
  fi

  local pdf_text
  pdf_text="$(texforge pdf text 2>/dev/null | head -500)"

  local explicit=(
    "Subtítulo Explícito"
    "Director Explícito"
    "Facultad Explícita"
    "Ciudad Explícita, País Explícito"
  )

  for exp in "${explicit[@]}"; do
    if ! echo "$pdf_text" | grep -q "$exp"; then
      echo "FAIL: Explicit value '$exp' not found in Spanish explicit render"
      return 1
    fi
  done

  local defaults=(
    "Un informe académico estructurado"
    "Nombre del director"
    "Facultad de Ingeniería"
    "Ciudad, País"
  )

  for def in "${defaults[@]}"; do
    if echo "$pdf_text" | grep -q "$def"; then
      echo "FAIL: Default value '$def' found in Spanish explicit render (should be overridden)"
      return 1
    fi
  done

  echo "PASS: Spanish with explicit values"
  return 0
}

# Main execution
FAILED=0

for lang in "${languages[@]}"; do
  if ! test_language "$lang"; then
    FAILED=1
  fi
done

if ! test_spanish_explicit; then
  FAILED=1
fi

if [[ $FAILED -eq 0 ]]; then
  echo ""
  echo "All language checks passed!"
  exit 0
else
  echo ""
  echo "Some language checks failed!"
  exit 1
fi
