# HARAMchy Rules Coverage

## Overview

HARAMchy enforces Islamic guidelines through a two-tier system:
- **Strict rules**: Hard blocks with immediate enforcement (siren + process kill)
- **Heuristic rules**: Soft warnings with configurable response (log, warn, block)

Rules are defined in `rules.yaml` and processed by `haramd`.

---

## Strict Rules (Hard Block)

These rules trigger immediate enforcement when matched with certainty.

| Rule ID | Category | Match Method | Action |
|---------|----------|--------------|--------|
| `pig_swine_pork` | Dietary | Keyword + package name | Kill process, siren |
| `alcohol_vodka` | Dietary | Keyword + URL domain | Kill process, siren |
| `casino_poker` | Gambling | Keyword + package name | Kill process, siren |
| `ramadan_fasting` | Worship | Time-based (prayer window) | Block network, siren |
| `usury_ribaa` | Finance | Package name + keyword | Kill process, siren |
| `zina_adult` | Moral | URL keyword | Kill process, siren |
| `shirk_idol` | Theology | Package name | Kill process, siren |
| `magic_sorcery` | Theology | Package name + keyword | Kill process, siren |

### Keyword Matching (Strict)
- Case-insensitive substring matching
- Matches in: process name, command line args, file paths, URLs
- Wildcard support: `*` at start/end of pattern
- Multi-word patterns: quoted strings match as phrase

### Package Name Matching (Strict)
- Exact package name match against known haram package lists
- Covers: PyPI, npm, AUR, Debian/Ubuntu package names
- Lists maintained in `rules.yaml` under `haram_packages`

---

## Heuristic Rules (Soft Warning)

These rules use heuristics and may produce false positives. Configurable via `config.toml`.

| Rule ID | Category | Heuristic | Response |
|---------|----------|-----------|----------|
| `idol_portrait` | Theology | EXIF analysis + file dimensions | Warn, log |
| `fortune_telling` | Theology | Package name + keyword | Warn, log |
| `music_instruments` | Entertainment | File extension + keyword | Warn, log |
| `excessive_screen` | Health | Time-based usage tracking | Warn, log |
| `nsfw_content` | Moral | URL keyword + header analysis | Block, siren |

### Idol/Portrait Detection (Heuristic)
- Analyzes image metadata (EXIF, dimensions)
- Flags images with human-proportion aspect ratios
- Uses file header signatures (JPEG/EXIF markers)
- Known limitation: No ML-based face detection (OpenCV not bundled)
- False positive rate: moderate (recommended: log-only mode initially)

### Fortune Telling (Heuristic)
- Matches package names containing: `astrology`, `horoscope`, `tarot`, `palm`, `numerology`
- Also checks command-line arguments for fortune-telling keywords
- Includes popular packages: `astropy`, `pythagora`, various npm packages

### Music Instruments (Heuristic)
- Detects audio file formats: `.mp3`, `.flac`, `.wav`, `.ogg`, `.m4a`
- Checks for media player executables: `vlc`, `mpv`, `spotify`, `rhythmbox`
- Flags music-related keywords in package names
- Configurable: can be set to warn-only or block

### Excessive Screen Time (Heuristic)
- Tracks total active screen time via logind sessions
- Configurable daily limit in `config.toml`
- Warning at threshold, block after hard limit
- Reset at Fajr prayer time

---

## Namaz (Prayer Time) Enforcement

### Prayer Time Calculation
- Astronomical formulas based on: latitude, longitude, timezone
- Supports: Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha
- Jumu'ah (Friday) prayer window enforced
- No internet connection required

### Enforcement Windows
- **Fajr**: Network blocked during prayer window (configurable offset)
- **Dhuhr**: Warnings 5 minutes before, block during prayer
- **Asr**: Same as Dhuhr
- **Maghrib**: Strict enforcement (siren if active haram process)
- **Isha**: Network blocked during prayer window

### Configuration
```toml
[prayer]
enforce = true
network_block = true
siren_on_violation = true
fajr_offset = -10    # minutes before calculated time
isha_offset = +10    # minutes after calculated time
```

---

## Rule Processing Pipeline

1. **Event received** (process start, network connect, file access)
2. **Rule matching**: Strict rules checked first (exact match)
3. **Heuristic fallback**: If no strict match, heuristic rules evaluated
4. **Action decision**: Based on rule severity and config settings
5. **Enforcement**: siren, process kill, network block, or log-only
6. **Audit logging**: All events logged to `/var/log/haramd/audit.log`

---

## Custom Rules

Users can add custom rules via `/etc/haramd/rules.d/`:

```yaml
# /etc/haramd/rules.d/custom.yaml
rules:
  - id: my_custom_rule
    category: custom
    type: strict
    keywords: ["badword1", "badword2"]
    packages: ["bad-package"]
    action: warn
```

Custom rules are merged with system rules at daemon startup.
