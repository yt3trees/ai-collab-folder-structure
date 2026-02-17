# obsidian-explorer

A Claude Code skill for searching, saving, and listing notes in an Obsidian vault.

Invokes PowerShell scripts via `powershell.exe -File` from a bash shell on Windows.

## Setup

### 1. Configure config.json

Set your Obsidian vault path in `config.json`. Save the file with UTF-8 BOM encoding.

```json
{
  "vaultPath": "C:\\Users\\YourUser\\Documents\\Obsidian"
}
```

The environment variable `OBSIDIAN_VAULT_PATH` is used as a fallback, but config.json is recommended because Japanese characters in paths get garbled when passed from bash.

### 2. .ps1 File Encoding

All .ps1 files must be saved with UTF-8 BOM (required for PowerShell 5.1 to correctly parse Japanese text).

How to re-save with BOM:

```powershell
$path = "target-file.ps1"
$content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($path, $content, $utf8Bom)
```

## File Structure

```
~/.claude/skills/obsidian-explorer/
  skill.md                  - Skill definition (referenced by Claude Code)
  config.json               - Vault path configuration
  Search-ObsidianNotes.ps1  - Search script
  Save-ObsidianNote.ps1     - Note saving script
  List-ObsidianNotes.ps1    - Note listing script
  README.md                 - This file
```

## Usage

### Full-Text Search

```bash
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Search-ObsidianNotes.ps1" -Pattern "keyword" -SearchType fulltext
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| -Pattern | Yes | - | Search keyword (supports regex) |
| -SearchType | No | fulltext | fulltext / filename / heading / tag |
| -Folder | No | "" | Target folder (relative path within vault) |
| -Context | No | 1 | Number of surrounding lines to display (fulltext only) |
| -MaxResults | No | 20 | Maximum number of results |

Search type descriptions:

- fulltext: Search file contents using regex
- filename: Search for notes whose filename contains the keyword
- heading: Search for notes with matching Markdown headings (# through ######)
- tag: Search for Obsidian tags (#keyword)

### Save Note

```bash
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Save-ObsidianNote.ps1" -Title "Title" -Content "Content"
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| -Title | Yes | - | Note title |
| -Content | Yes | - | Note content (Markdown) |
| -Folder | No | "" | Destination folder (relative path within vault) |

The filename is auto-generated in the format `yyyy-MM-dd-Title.md`.

### List Notes

```bash
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/List-ObsidianNotes.ps1" -Days 7
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| -Days | No | 7 | Show notes from the last N days |
| -MaxResults | No | 20 | Maximum number of results |

## Examples

```bash
# Search notes by filename for GRANDIT
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Search-ObsidianNotes.ps1" -Pattern "GRANDIT" -SearchType filename

# Full-text search within a specific folder, showing 3 surrounding lines
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Search-ObsidianNotes.ps1" -Pattern "error" -Folder "_GRANDIT" -Context 3

# Search for notes with "trouble" in headings
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Search-ObsidianNotes.ps1" -Pattern "trouble" -SearchType heading

# List notes from the last 30 days, up to 50 results
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/List-ObsidianNotes.ps1" -Days 30 -MaxResults 50

# Save a note to the Projects folder
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.claude/skills/obsidian-explorer/Save-ObsidianNote.ps1" -Title "Research Notes" -Content "Research content" -Folder "Projects"
```

## Performance

Full-text search may be slow when the vault is located in a cloud-synced folder (e.g., Box). As a countermeasure, the script uses `[System.IO.File]::ReadAllLines` for bulk reading to minimize I/O operations.

For further optimization:
- Use `-Folder` to narrow the search scope
- Use `-MaxResults` to limit the number of results
- Use `-SearchType filename` to filter by filename without reading file contents

## Troubleshooting

### Garbled characters when running scripts

Verify that .ps1 files are saved with UTF-8 BOM encoding.

### Vault path not found error

Check that the path in config.json is correct. Path separators must be escaped with `\\`.

### Search returns zero results

- Regex special characters (`.*+?[](){}`) may not be properly escaped
- For simple string searches, use a pattern equivalent to `[regex]::Escape("search string")`
