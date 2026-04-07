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
description = "Document language"
required = false
choices = ["es", "en", "fr"]
default = "es"

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
| `enum` | `language = "es"` | Must have `choices` array |

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

## Placeholder Usage in Templates

Use `{{placeholder_name}}` in `.tex` files for substitution:

```latex
\title{{{title}}}
\author{{{author}}}
\date{{{date}}}
```

The texforge generator will replace `{{title}}` with the resolved value.

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
2. **Update `registry.toml`**:

```toml
[[templates]]
nombre = "my-template"
descripcion = "Short description of the template"
version = "1.0.0"
```

3. **Validate**: Run `texforge template validate ./my-template` (coming in Phase 2)
4. **Test generation**: Create a test project and verify placeholders are substituted correctly
5. **Open a PR** with a description of:
   - What use case the template addresses
   - Any special placeholders or features
   - Whether it requires specific LaTeX packages beyond standard distributions

## Questions

Open an issue in the [texforge repository](https://github.com/UniverLab/texforge) or check the main CLI docs.

