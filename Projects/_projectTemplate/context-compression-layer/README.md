# Context Compression Layer

A compressed intermediate layer that enables AI to instantly grasp the vast knowledge accumulated in the Obsidian Vault (Layer 2).

```
Layer 1: Execution (WIP)     <- Where AI works
Layer 2: Knowledge (Vault)   <- Source of knowledge (vast)
  ↓ Compression
★ Context Compression Layer  <- A lens for AI to understand "now"
Layer 3: Artifact (BOX)      <- Deliverables
```

## Why It's Needed

- AI forgets context every session -> Feed it a compressed "current state" each time
- Reading the entire Vault reduces accuracy -> Condense only the necessary information
- Some work happens without AI -> AI reads human-written "what I'm doing now"
- Long-term project context gets lost -> decision_log ensures continuity of decisions

## Structure

### Per-Project (extends `_ai-context/`)

```
{ProjectName}/
├── _ai-context/
│   ├── project_summary.md     ★ Project overview
│   ├── current_focus.md       ★ Current focus (mainly written by humans)
│   ├── focus_history/         ★ Daily snapshots of current_focus.md
│   ├── decision_log/          ★ Decision log
│   │   └── TEMPLATE.md
│   └── obsidian_notes/        (Existing. Do not modify)
├── CLAUDE.md                  (Existing. Append CCL instructions)
```

### Workspace-wide (optional)

```
Documents/Projects/
├── .context/
│   ├── workspace_summary.md   Workspace overview
│   ├── current_focus.md       This week's focus
│   └── active_projects.md     Project list and status
├── CLAUDE.md                  (Existing. Append CCL instructions)
```

## Who Writes What

| File | Human | AI |
|------|-------|-----|
| current_focus.md | Primary author (overwrite in 30 seconds) | Suggests `[AI]` tagged additions at work boundaries |
| project_summary.md | Initial creation + major changes | Proposes updates at milestone changes |
| decision_log/*.md | Communicates decisions from meetings, etc. | Generates drafts. Humans approve and save |

### current_focus.md Usage

Overwrite-based operation. Always keep it at 10-20 lines as a "snapshot of now".

- Completed tasks -> Remove them
- Old "recent events" -> Remove them (keep only the last 1-2 weeks)
- Items needing history -> Handled by decision_log / Obsidian Vault / git log
- Daily snapshots are saved to `focus_history/YYYY-MM-DD.md` via `save_focus_snapshot.ps1`

## Setup Guide

### Step 1: Append to CLAUDE.md (this alone makes it work)

Append the contents of `templates/CLAUDE_MD_SNIPPET.md` to the project's CLAUDE.md.

### Step 2: Create current_focus.md

Write bullet points about what you're currently doing in `_ai-context/current_focus.md`.

### Step 3: Create project_summary.md

You can have AI draft this. It can be refined later.

### Step 4: Deploy Agent Skills (optional)

```bash
# Deploy skills to Claude Code
cp -r skills/context-init ~/.claude/skills/
cp -r skills/context-session-end ~/.claude/skills/
cp -r skills/context-decision-log ~/.claude/skills/
```

Steps 1-2 provide the core functionality. Skills are additional conveniences.

## Automation Levels

| Level | Action | Effect |
|-------|--------|--------|
| 0 | Just write current_focus.md manually | AI can understand the current state |
| 1 | Append instructions to CLAUDE.md | AI auto-reads + freshness checks |
| 2 | Introduce Agent Skills | Auto-generate decision_log, suggest additions at session end |
| 3 | Claude Code Hooks | Fully automate current_focus.md freshness warnings |

## Agent Skills List

| Skill | Role | Trigger |
|-------|------|---------|
| context-init | CCL setup and initialization | "Set up context layer" (first time only) |
| context-session-end | Suggest AI work additions at work boundaries | Natural boundaries ("thanks", "let's stop here", etc.) |
| context-decision-log | Structured recording of decisions + detection of implicit decisions | At decision time or detection |

What was not made into a skill:
- Session start reading -> CLAUDE.md instructions are sufficient
- Implicit decision detection -> Integrated into decision-log skill

## File Structure

```
context-compression-layer/
├── README.md                           This file
├── README-ja.md                        Japanese documentation
├── templates/
│   ├── CLAUDE_MD_SNIPPET.md            ★ Most important: content to append to CLAUDE.md
│   ├── current_focus.md                Lightweight template for humans
│   ├── project_summary.md             Project overview
│   ├── decision_log_TEMPLATE.md       Decision log
│   ├── workspace_summary.md           Workspace overview (optional)
│   └── active_projects.md             Project list (optional)
├── examples/
│   ├── current_focus_example.md
│   ├── project_summary_example.md
│   └── decision_log_example.md
├── skills/
│   ├── context-init/SKILL.md
│   ├── context-session-end/SKILL.md
│   └── context-decision-log/SKILL.md
├── setup_context_layer.ps1            Setup script
└── save_focus_snapshot.ps1            Daily snapshot of current_focus.md
```
