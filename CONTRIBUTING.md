# Contributing to texforge-templates

Thanks for wanting to contribute a template! This guide explains how to create and submit one following texforge Phase 1 specifications.

## Template Structure

Every template is a directory with this layout:

```
my-template/
├── template.toml     ← required: manifest with metadata and placeholders
├── main.tex          ← required: entry point
├── sections/         ← optional: additional .tex files
├── bib/              ← optional: bibliography files
└── assets/           ← optional: images, fonts, etc.
```

## `template.toml` Manifest Format

The manifest declares template metadata, placeholders, and post-generation scripts.

### Minimal Example

```toml
id = "my-template"
version = "1.0.0"
display_name = "My Template"
description = "A brief description of what this template is for"

[files]
include = ["**/*.tex", "**/*.bib"]      # glob patterns to include
exclude = []                             # glob patterns to exclude

[[placeholders]]
name = "title"
type = "string"                          # string | boolean | enum
description = "Document title"
required = true                          # must be provided
# default = "Default Title"             # optional: fallback value

[[placeholders]]
name = "author"
type = "string"
description = "Author name"
required = true
default = "{{user.name}}"                # can reference config: {{user.name}}, {{institution.name}}

[[placeholders]]
name = "language"
type = "enum"
description = "Document language (for babel/polyglossia)"
required = true
choices = ["english", "spanish", "french", "german", "italian", "portuguese"]
default = "english"

[[post_generate]]
name = "build"
description = "Compile the template to PDF"
command = "texforge build"
optional = true                          # user can skip this script
```

### Placeholder Types

| Type | Example | Notes |
|------|---------|-------|
| `string` | `title = "My Document"` | Free-form text |
| `boolean` | `draft = true` | true or false |
| `enum` | `language = "english"` | Must have `choices` array |

### Default Value Interpolation

Default values can reference user config via `{{key}}`:

- `{{user.name}}` — from `~/.texforge/config.toml` [user] section
- `{{user.email}}` — user email
- `{{institution.name}}` — institution name
- `{{institution.address}}` — institution address

Example:

```toml
[[placeholders]]
name = "author"
type = "string"
default = "{{user.name}}"
```

If the user has configured `user.name = "Jane Doe"`, the default will be "Jane Doe".

### Placeholder Precedence Chain

When generating a project, placeholders are resolved in this order:

1. **CLI arguments** (highest priority) — `texforge new myproj -t my-template --title "My Doc"`
2. **Project config** — `./.texforge/config.toml`
3. **User config** — `~/.texforge/config.toml`
4. **Template defaults** — values in this `template.toml`
5. **Interactive prompt** — if required and no value found in chain above

## Multi-Language Support

All templates should include a `language` placeholder to support multi-language output via babel/polyglossia:

```latex
\usepackage[{{language}}]{babel}
```

Recommended language choices in `template.toml`:

```toml
[[placeholders]]
name = "language"
type = "enum"
description = "Document language (for babel/polyglossia)"
required = true
choices = ["english", "spanish", "french", "german", "italian", "portuguese"]
default = "english"
```

### Template Content Language

To ensure portability and broad usability:
- Write all template example text in **English**
- Use placeholder values that are language-agnostic
- Avoid hardcoding language-specific strings in the template content (e.g., instead of hardcoding "Introduction", use placeholders or rely on babel's auto-translation)

## Placeholder Usage in Templates

Use `{{placeholder_name}}` in `.tex` files for substitution:

```latex
\documentclass[a4paper,12pt]{article}
\usepackage[{{language}}]{babel}

\title{{{title}}}
\author{{{author}}}
\date{{{date}}}
```

The texforge generator will replace `{{language}}` with the user's configured language, and other placeholders with their resolved values.

### Rules

- **Tokens**: Syntax is `{{placeholder}}` (double braces)
- **Text files only**: Only UTF-8 text files are processed (`.tex`, `.bib`, etc.)
- **Binary files**: Images, fonts, PDFs are copied as-is without substitution
- **Incomplete substitution**: If a required placeholder has no value and is not resolved, the generator returns an error with a clear message

## Compatibility Requirements

Templates must work with [tectonic](https://tectonic-typesetting.github.io/) as the LaTeX engine. Tectonic resolves packages automatically, but **avoid packages that require external binaries**:

| ❌ Incompatible | ✅ Alternative |
|---|---|
| `minted` (needs `pygmentize`) | `listings` |
| `gnuplottex` (needs `gnuplot`) | TikZ |
| `svg` (needs `inkscape`) | Embed as PNG/PDF |

### Diagram Support

If your template supports embedded Mermaid or Graphviz diagrams, declare this in `template.toml`:

```toml
# Coming in Phase 2: diagram metadata
```

For now, ensure the template includes packages that support figure environments:

```latex
\usepackage{graphicx}  % for \includegraphics
\usepackage{float}     % for [H] figure placement
```

## Post-Generation Scripts

The `[[post_generate]]` section lists optional scripts the user can run after template generation.

**Phase 1 Note:** Scripts are **never executed automatically**. The generator lists them and the user decides whether to run them manually. This is a security measure — templates should not execute arbitrary code without explicit consent.

Best practices:

- Only suggest scripts that are truly optional (e.g., "install dependencies")
- Document what each script does and why it's optional
- Never include scripts that require external API keys or credentials

Example:

```toml
[[post_generate]]
name = "install-deps"
description = "Download and cache required LaTeX packages"
command = "texforge build --dry-run"
optional = true
```

## Security Guidelines

- **No auto-execution**: Scripts in `post_generate` are informational only. Never assume they will run.
- **No remote scripts**: Do not include shell scripts that download and execute code from the internet.
- **No credentials**: Never hardcode API keys, passwords, or tokens in templates.
- **No side effects**: Templates should only generate files; avoid modifying system config or installing software.

## Submitting a Template

1. **Create your template** following the structure above
2. **Update `registry.toml`** (alphabetically sorted):

```toml
[[templates]]
nombre = "my-template"
descripcion = "Short description of the template"
version = "1.0.0"
```

3. **Validate**: Run `texforge fmt` to format your template files
4. **Test generation**: Create a test project and verify:
   - All placeholders are correctly substituted
   - Language switching works via the `{{language}}` placeholder
   - PDF generation succeeds with `texforge build`
5. **Open a PR** with a description of:
   - What use case the template addresses
   - Any special placeholders or features
   - Languages supported
   - Whether it requires specific LaTeX packages beyond standard distributions

## Checking a template

`check-templates.sh` (at the repo root, not in a folder: texforge lists every
top-level directory of this repo as a template) validates templates offline: it never runs
`texforge new` (which would refresh cached templates from the remote registry
and test the published copy instead of your working tree), it renders into a
throwaway temp directory, and it never writes to `~/.texforge`. Every template
spec in the development queue is gated by this script.

### Usage

```bash
# Check every template (any top-level directory with a template.toml)
./check-templates.sh

# Check exactly those templates (unknown name exits 2)
./check-templates.sh taller general

# Check only templates changed since a revision (tracked changes + untracked files)
./check-templates.sh --changed HEAD
```

### What each step checks

For each template the steps run in order; the first failing step stops that
template (the next template still runs).

| Step | Name | Checks |
|------|------|--------|
| a | manifest | `template.toml` parses; `id` equals the directory name; `version` matches `^[0-9]+\.[0-9]+\.[0-9]+$`; `registry.toml` has a `[[templates]]` entry with `nombre = <name>` and the same `version` |
| b | placeholders | every `{{token}}` in the template's files (except `template.toml` itself) is declared as a `[[placeholders]]` `name`, or is one of `user.name`, `user.email`, `institution.name` |
| c | render | the template is copied to a temp dir (without `template.toml`), every `{{token}}` is replaced with its `default` (or a `Sample …` stand-in), and a `project.toml` is written (`[document]` + `[build] entry = "main.tex"`, plus `bibliography = "bib/references.bib"` when that file exists) |
| d | texforge | in the rendered copy: `texforge check` exits 0 **and** prints no line matching `WARNING\|ERROR`; `texforge fmt --check` exits 0; `texforge build` exits 0; `texforge pdf check` exits 0 |
| e | previews | `texforge preview --scale 1.5` writes PNG pages into `<git-dir>/template-previews/<name>/` (the directory is emptied first), and the page count is read from `texforge pdf info` |
| f | content | *(requirements skipped for `letter` and `cv`)* `main.tex` or a file it `\input`s contains a `\begin{code}[lang=…]` block, and at least one `\begin{mermaid}` / `\begin{graphviz}` / `\begin{d2}` whose options contain `style=`. For **every** template: no `\usepackage[utf8]{inputenc}`, no `\lstdefinestyle`, no `\begin{lstlisting}`, no `\usepackage{minted}` |

### Where previews land

Previews are written to `<git-dir>/template-previews/<template-name>/`
(normally `.git/template-previews/…`). Because they live inside the git dir
they are never committed and never show up in `git status` — nothing needs to
be added to `.gitignore`.

### Output and exit codes

The script prints one `Checking <name> ...` line per template, then a summary
table (`template  pages  result`) with `ok` or `FAIL: <step> — <reason>`. On a
failure it also prints the last 40 lines of the failing command's output.

| Exit code | Meaning |
|---|---|
| 0 | every selected template passed all steps |
| 1 | at least one template failed |
| 2 | an unknown template name was requested |

## Questions

Open an issue in the [texforge repository](https://github.com/UniverLab/texforge) or check the main CLI docs.

