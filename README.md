# texforge-templates

Official template registry for [texforge](https://github.com/JheisonMB/texforge).

## Available Templates

All templates support **multi-language output** via the `{{language}}` placeholder. Supported languages: English, Spanish, French, German, Italian, Portuguese.

| Template | Description | Version |
|----------|-------------|---------|
| `general` | Generic article — minimal setup for any document | 0.2.0 |
| `article` | Simple article — clean, portable academic article | 0.1.0 |
| `report` | University report — structured academic report template | 0.2.0 |
| `apa-general` | APA 7th edition — academic reports and theses | 0.2.0 |
| `apa-unisalle` | APA for Universidad de La Salle — thesis proposal format | 0.2.0 |
| `ieee` | IEEE journal format — technical papers | 0.2.0 |
| `letter` | Formal letter template — professional correspondence | 0.1.0 |
| `taller` | Taller / informe con portada en color, bloques de código y diagrama de flujo — informal pero atractivo | 0.2.0 |
| `informe` | Informe relajado con portada, cajas destacadas, diagramas y código — para entregas y notas técnicas | 0.1.0 |
| `cv` | Curriculum vitae — clean, ATS-friendly résumé | 0.1.0 |

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
