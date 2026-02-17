---
name: obsidian-explorer
description: "Search, read, save, and list notes in an Obsidian vault. Triggers on: 'search notes', 'find memos', 'save to Obsidian', 'show recent notes'."
---

## Overview

This skill enables users to efficiently search, read, organize, and save notes stored in an Obsidian vault. It runs on Windows using PowerShell scripts (.ps1) invoked from a bash shell via `powershell.exe -File`. Full-text search (`-SearchType fulltext`) uses ripgrep (`rg.exe`) located under the `bin` directory within this skill.

## Prerequisites

### Vault Path Configuration

Set your Obsidian vault path in `config.json` (save with UTF-8 BOM). A config file is used instead of environment variables because Japanese characters in paths get garbled when passed from bash. Windows environment variables such as `%USERPROFILE%` can also be used.

```json
{
  "vaultPath": "%USERPROFILE%\\Documents\\Obsidian"
}
```

The environment variable `OBSIDIAN_VAULT_PATH` is used as a fallback.

### Script Location

All scripts are located under `~/.claude/skills/obsidian-explorer/script/`.

- `script/Search-ObsidianNotes.ps1` - Search script
- `script/Save-ObsidianNote.ps1` - Note saving script
- `script/List-ObsidianNotes.ps1` - Note listing script
- `script/Get-ObsidianNote.ps1` - Note reading (content retrieval) script

### ripgrep Setup

ripgrep is required for full-text search. Place `rg.exe` in one of the following locations:

- Recommended: `~/.claude/skills/obsidian-explorer/bin/rg.exe`
- Alternatively, any subfolder under `bin` (e.g., `bin/ripgrep-15.1.0-aarch64-pc-windows-msvc/rg.exe`)

`Search-ObsidianNotes.ps1` recursively searches under the `bin` directory from the project root and uses the first `rg.exe` found. If none is found, the script exits with an error.

---

## Search (Search-ObsidianNotes.ps1)

Search notes in the Obsidian vault by keyword.

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| -Pattern | Yes | - | Search keyword (supports regex) |
| -SearchType | No | fulltext | Search type: fulltext / filename / heading / tag |
| -Folder | No | "" | Target folder (relative path within vault) |
| -Context | No | 1 | Number of surrounding lines to display (fulltext only) |
| -MaxResults | No | 20 | Maximum number of results |

### Usage Examples

```bash
# Full-text search
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "GRANDIT.*timeout" -SearchType fulltext

# Filename search
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "GRANDIT" -SearchType filename

# Heading search
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "performance" -SearchType heading

# Tag search
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "todo" -SearchType tag

# Search within a specific folder, showing 3 surrounding lines
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "error" -Folder "Projects" -Context 3

# Display up to 50 results
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "TypeScript" -MaxResults 50
```

---

## Save Note (Save-ObsidianNote.ps1)

Create a new note and save it to the vault. A date prefix (yyyy-MM-dd) is automatically added to the filename.

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| -Title | Yes | - | Note title |
| -Content | Yes | - | Note content (Markdown) |
| -Folder | No | "" | Destination folder (relative path within vault) |

### Usage Examples

```bash
# Save to the vault root
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Save-ObsidianNote.ps1" -Title "Meeting Notes" -Content "## Agenda\n\n- Item 1\n- Item 2"

# Save to a specific folder
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Save-ObsidianNote.ps1" -Title "Research Results" -Content "Content" -Folder "Projects/Research"
```

---

## List Notes (List-ObsidianNotes.ps1)

Display a list of recently updated notes.

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| -Days | No | 7 | Show notes from the last N days |
| -MaxResults | No | 20 | Maximum number of results |

### Usage Examples

```bash
# List notes from the last 7 days
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/List-ObsidianNotes.ps1"

# List notes from the last 30 days, up to 50 results
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/List-ObsidianNotes.ps1" -Days 30 -MaxResults 50
```

Output example:

```text
UPDATED:2026-02-16 12:34|PATH:Projects/XXX/note.md
UPDATED:2026-02-15 09:10|PATH:Inbox/note2.md
```

The AI can parse each line starting with `UPDATED:` to extract the relative path (`PATH:`).

---

## Read Note (Get-ObsidianNote.ps1)

Retrieve the content of a specified note file. Supports three modes: full text, first N lines preview, and section by heading.

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| -Path | Yes | - | Note file path (relative path within vault, e.g., `Projects/XXX/note.md`) |
| -Mode | No | full | Retrieval mode: full / preview / section |
| -PreviewLines | No | 40 | Number of lines to retrieve when Mode=preview |
| -Heading | No | "" | Heading text to retrieve when Mode=section (e.g., `Results` or `## Results`) |

### Output Format

All modes output in a fixed format that is easy for the AI to parse.

```text
---OBSIDIAN-NOTE-BEGIN---
PATH: relative/path/to/note.md
MODE: full|preview|section
HEADING: heading name (section mode only)
---CONTENT-START---
(note content or excerpt here)
...
---CONTENT-END---
---OBSIDIAN-NOTE-END---
```

The AI should extract the body text from between `---CONTENT-START---` and `---CONTENT-END---`.

### Usage Examples

```bash
# Get full note content
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/note.md" -Mode full

# Preview first 60 lines
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/note.md" -Mode preview -PreviewLines 60

# Get a specific section by heading
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/note.md" -Mode section -Heading "Results"

# Full heading specification is also supported
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/note.md" -Mode section -Heading "## Results"
```

---

## Search Workflow Examples

### Case 1: "Tell me what I've noted about performance"

```bash
# Step 1: Tag search
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "performance" -SearchType tag

# Step 2: Heading search
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "performance" -SearchType heading

# Step 3: Full-text search
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "performance improvement|optimization" -SearchType fulltext -Context 2
```

### Case 2: "I want to check my recent notes"

```bash
# Get the list of notes from the last 7 days
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/List-ObsidianNotes.ps1" -Days 7

# Use the PATH from the output to retrieve the full content of a specific note
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/note.md" -Mode full
```

### Case 3: "Save this as a note"

```bash
# Save the note
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Save-ObsidianNote.ps1" -Title "Title" -Content "Content to save" -Folder "Notes"

# To review the content later
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/List-ObsidianNotes.ps1" -Days 1
# Get the PATH of the latest note and read its content
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Notes/2026-02-16-Title.md" -Mode preview -PreviewLines 40
```

### Case 4: "I only want to read a specific heading"

```bash
# Search for notes with "performance" in headings
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Search-ObsidianNotes.ps1" -Pattern "performance" -SearchType heading

# Use the PATH and heading name from the output to retrieve just that section
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/script/Get-ObsidianNote.ps1" -Path "Projects/XXX/note.md" -Mode section -Heading "performance"
```

---

## Guidelines

- Write searchable notes: use specific terms, leverage headings and tags
- Use descriptive filenames: include dates and categories for easier retrieval
- Organize folder structure: categorize by purpose such as Projects, Work, Learning (2-3 levels deep)
- Only save information worth reusing; periodically clean up temporary notes

---

## Troubleshooting

### Environment variable not recognized

```bash
# Check from bash
powershell.exe -Command "echo \$env:OBSIDIAN_VAULT_PATH"
```

Add `$env:OBSIDIAN_VAULT_PATH = "path"` to your PowerShell profile (`$PROFILE`).

### Japanese characters are garbled

UTF-8 encoding is specified within the scripts. If the issue persists, check your terminal's encoding settings.

### Too many search results

- Use `-MaxResults` to limit the number of results
- Use `-Folder` to narrow the search scope
- Use `-SearchType filename` or `heading` to refine the search
- Combine multiple keywords with regex (e.g., `keyword1.*keyword2`)
