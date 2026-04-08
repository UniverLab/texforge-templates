# texforge-templates

Official template registry for [texforge](https://github.com/JheisonMB/texforge).

## Available Templates

All templates support **multi-language output** via the `{{language}}` placeholder. Supported languages: English, Spanish, French, German, Italian, Portuguese.

| Template | Description |
|----------|-------------|
| `general` | Generic article — minimal setup for any document |
| `article` | Simple article — clean, portable academic article |
| `report` | University report — structured academic report template |
| `apa-general` | APA 7th edition — academic reports and theses |
| `apa-unisalle` | APA for Universidad de La Salle — thesis proposal |
| `ieee` | IEEE journal format — technical papers |
| `letter` | Formal letter — professional correspondence |

## Usage

```bash
# Create a project with the default template (general)
texforge new my-project

# Create a project with a specific template
texforge new my-article -t article

# Interactive wizard to set language and other placeholders
texforge init

# Build a project
texforge build
```

## Template Structure

Each template contains:

```
template-name/
├── template.toml     # Metadata and configuration
├── main.tex          # Entry point
├── bib/
│   └── references.bib
└── sections/
    └── ...
```

## License

MIT
