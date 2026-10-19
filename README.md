# texforge-templates

Official template registry for [texforge](https://github.com/JheisonMB/texforge).

## Available Templates

All templates support **multi-language output** via the `{{language}}` placeholder. Supported languages: English, Spanish, French, German, Italian, Portuguese.

| Template | Description | Version |
|----------|-------------|---------|
| `apa-general` | APA 7th edition template for academic reports and theses | 0.2.0 |
| `apa-unisalle` | APA thesis proposal for Universidad de La Salle | 0.2.0 |
| `article` | Single-column academic article with running heads and author affiliations | 0.3.0 |
| `book` | Long-form book layout with epigraphs and front matter | 0.2.0 |
| `cv` | Curriculum vitae — clean, ATS-friendly résumé | 0.1.0 |
| `general` | Editorial foundation for essays and other documents; serif type and spaced paragraphs | 0.3.0 |
| `ieee` | IEEE journal format for technical papers | 0.2.0 |
| `letter` | Formal letter template for professional correspondence | 0.2.0 |
| `report` | Structured university report with front matter, contents and appendices | 0.3.0 |
| `slides` | 16:9 presentation slides with code and diagrams | 0.1.0 |
| `technical-brief` | Concise technical update with callouts, diagrams, code and results | 0.2.0 |
| `workshop` | Workshop handout with a cover page, workflow, code and test table | 0.3.0 |

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
