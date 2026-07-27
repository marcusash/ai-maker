# Skill 10: Vault

The Vault is the human's working memory. When they say "save this to the vault," "remember this for later," "put that somewhere I can find it," or "file this away" -- the Vault is where it goes.

The Vault lives at `C:\AIMaker\vault\`. Four subfolders. Max 20 items total. If it does not belong here, it does not go here.

---

## The Four Vaults

| Subfolder | What belongs here | When the human says... |
|-----------|------------------|------------------------|
| `how-to\` | Step-by-step guides they will run again | "Save how to do this" / "I want to remember these steps" |
| `proposals\` | Docs awaiting a decision or review | "File this proposal" / "Put this somewhere I can find it before the meeting" |
| `references\` | Things they look up repeatedly | "Save this as a reference" / "I keep forgetting this, remember it for me" |
| `decisions\` | Decisions that are final, written down | "Record this decision" / "Let's write that down so we don't revisit it" |

---

## The Workflow

1. Human says something like: "put that in the vault" or "save that decision"
2. You determine which subfolder based on what it is (ask if unclear)
3. You write a well-structured markdown file to the right subfolder
4. You tell the human the full path: `C:\AIMaker\vault\decisions\no-em-dashes.md`
5. If it is a decision, add a one-line entry to `C:\AIMaker\vault\decisions\index.md`

Always confirm with the human before writing. One sentence: "I am saving this as a decision in the vault. Ready?"

---

## File Naming

Clear, lowercase, hyphen-separated. Date prefix only if the content is time-bound.

```
vault\how-to\run-weekly-review.md
vault\proposals\q2-budget-framework.md
vault\references\team-contacts.md
vault\decisions\no-redesign-before-q3.md
```

---

## The 20-Item Rule

The vault holds the 20 most important things. Not 21. If the human wants to add something and there are already 20 items, say: "The vault has 20 items. Which one would you like to remove to make room for this one?" Then move the old one to their Desktop or Documents.

Check the count before adding: `Get-ChildItem C:\AIMaker\vault -Recurse -File -Filter *.md | Where-Object { $_.Name -ne 'README.md' -and $_.Name -ne 'index.md' } | Measure-Object`

---

## Vault File Format

Every vault file follows this structure:

```markdown
# [Title]

**Saved:** YYYY-MM-DD
**Type:** [how-to / proposal / reference / decision]

---

[Content here. Concise. Written in the human's voice.]

---

*Saved by AI Maker on YYYY-MM-DD.*
```

---

## Reading the Vault

When the human asks "what's in my vault?" or "what have I saved?" or "do I have anything on [topic]?":

1. List the vault contents grouped by subfolder
2. For each item: title and one-sentence summary
3. Ask if they want to open any of them

Example response:
```
Your vault has 7 items:

Decisions (2):
  - No redesign before Q3 (2026-02-10)
  - Weekly reviews on Fridays (2026-02-15)

References (3):
  - Team contacts
  - Q2 budget numbers
  - Key stakeholder map

How-to (1):
  - Run the weekly review

Proposals (1):
  - Headcount request for H2

Open any of these?
```

---

## What the Vault Is Not

- Not a file dump. If something is "nice to have later," it does not go in the vault.
- Not a to-do list. Tasks belong in chat or the human's task manager.
- Not a meeting notes archive. Summaries of specific meetings belong in the proposal or reference folders only if they contain something the human will actively look up again.

---

## Example Natural Language Triggers

| The human says | What you do |
|----------------|-------------|
| "Save this to the vault" | Ask which subfolder if unclear, write and confirm path |
| "Remember this for me" | Save as reference, confirm path |
| "Let's write that decision down" | Save as decision, add to index.md, confirm path |
| "Put these steps somewhere" | Save as how-to, confirm path |
| "What's in my vault?" | List all vault items with summaries |
| "Do I have anything on [topic]?" | Search vault files for the topic, summarize matches |
| "File this proposal" | Save as proposal, confirm path |
