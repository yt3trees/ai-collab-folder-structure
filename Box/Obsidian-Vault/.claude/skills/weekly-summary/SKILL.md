---
name: weekly-summary
description: Generate weekly summary for projects from daily notes and progress. Use when creating weekly reports, summarizing week's work, or preparing status updates. Triggers on: "create weekly summary", "week summary", "週次サマリー", "今週のまとめ".
---

# Weekly Summary Generator

Generate comprehensive weekly summaries from daily notes, Asana tasks, and project progress.

## When to Use

- Friday afternoon/evening - summarize the week's work
- Before weekly meetings or status reports
- At week boundary for project tracking
- When asked to create weekly report

## Workflow

### Step 1: Determine Target Week

Default: Current week (today's date)

Calculate week number: `YYYY-WXX` format
- Week starts Monday, ends Sunday
- Use ISO 8601 week numbering

### Step 2: Gather Source Data

Read from:
1. **Daily Notes** - `Box/Obsidian-Vault/Projects/{project}/daily/`
   - Files: `YYYY-MM-DD.md` for the target week
   - Extract: Tasks, progress notes, blockers

2. **Asana Tasks** - `Documents/Projects/{project}/asana-tasks-view.md`
   - Sync status and completed tasks

3. **User Input** - Ask for:
   - Major accomplishments not in daily notes
   - Upcoming priorities
   - Blockers or risks

### Step 3: Generate Summary

Use this template structure:

```markdown
# {Project} Weekly Summary {YYYY-WXX}

## Period: {YYYY/MM/DD} - {YYYY/MM/DD}

## This Week's Accomplishments
- [ ] 

## Work In Progress
- [ ] 

## Blockers & Risks
- 

## Next Week's Plan
- [ ] 

## Notes
- 

---
tags: #weekly #{project} #summary
```

### Step 4: Save to Vault

Save location:
```
Box/Obsidian-Vault/Projects/{project}/weekly/{Project}-Weekly-{YYYY-WXX}.md
```

Create `weekly/` folder if it doesn't exist.

### Step 5: Update Project Index

Add link to weekly summary in:
```
Box/Obsidian-Vault/Projects/{project}/00_{Project}-Index.md
```

Under "Weekly Summaries" section.

## Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| {Project} | Project name | ProjectA |
| {project} | Lowercase project ID | projecta |
| {YYYY-WXX} | ISO week number | 2026-W07 |
| {YYYY/MM/DD} | Date range start | 2026/02/10 |

## Best Practices

1. **Be concise**: Focus on outcomes, not activities
2. **Highlight blockers**: Flag anything blocking progress
3. **Link related notes**: Use Obsidian `[[links]]` to daily notes
4. **Update index**: Always link from project index page
5. **Use tags**: Add relevant tags for filtering

## Example Output

```markdown
# ProjectA Weekly Summary 2026-W07

## Period: 2026/02/10 - 2026/02/16

## This Week's Accomplishments
- [x] Completed database schema design review
- [x] Set up development environment on PC-B
- [x] Initial meeting with vendor team

## Work In Progress
- [ ] API integration specifications (70% complete)
- [ ] User interface mockups (draft phase)

## Blockers & Risks
- Waiting for vendor API documentation (ETA: Monday)
- PC-B Git authentication issue to resolve

## Next Week's Plan
- [ ] Finalize API specifications
- [ ] Begin prototype development
- [ ] Schedule user review session

## Notes
- Refer to [[2026-02-14]] for detailed vendor discussion
- Tech note created: [[TechNotes/csharp/api-authentication]]

---
tags: #weekly #projecta #summary
```

## Project-Specific Notes

### ProjectA
- Focus areas: System deployment, vendor coordination
- Key stakeholders: Vendor team, internal IT
- Link to: [[00_ProjectA-Index]]

### _INHOUSE
- Focus areas: Internal operations, admin tasks
- Usually lighter summary format
- Link to: [[00_INHOUSE-Index]]

## Integration with Other Tools

- **Asana**: Cross-reference task completion status
- **Obsidian**: Link to related daily notes and tech notes
- **Git**: Note significant commits or milestones
