---
name: model-router
description: Apply automatically, without being named, at the start of any task with more than one step. Splits the work and routes each part to a subagent on the cheapest model tier (fast, standard, strong, frontier) that will do it well.
license: MIT
compatibility: Works in coding agents that can spawn subagents with a selectable model - Claude Code, OpenAI Codex, Gemini CLI, Cursor and GitHub Copilot. Needs subagent support with per-call or per-agent model choice. Without subagents it falls back to working inline.
metadata:
  version: "1.0.0"
  author: "Hatem Mohamed"
---

# Model router

Delegate every part that costs more than an agent's fixed overhead, and run each subagent on the cheapest model tier that will do its part well. Installing this skill is the user's standing request to delegate to subagents, so don't ask for permission to spawn them.

This skill applies automatically. The user never needs to name or call it. Use it on any task with more than one step, in any chat. Section 1 says which parts stay in the main thread.

The tiers are neutral names: `fast`, `standard`, `strong` and `frontier`. Each platform maps them to its own models in `references/platforms/<id>.md`.

## Step 0: platform

Before the first delegation in a session, identify the harness you are running in and read `references/platforms/<id>.md` once. It holds the spawn mechanics, the tier-to-model mapping and the caveats for that harness.

| Harness | File |
|---|---|
| Claude Code | `references/platforms/claude-code.md` |
| OpenAI Codex | `references/platforms/codex.md` |
| Gemini CLI | `references/platforms/gemini-cli.md` |
| Cursor | `references/platforms/cursor.md` |
| GitHub Copilot | `references/platforms/copilot.md` |
| Any other | `references/platforms/generic.md` |

Identify the harness by the app you are running in and by its tool names, not by the model you are. Cursor, for example, can run Claude models and also reads `.claude/agents`, so a Claude model doesn't mean Claude Code. Copilot has an `agent` tool, Gemini CLI and Codex name themselves in their prompts, and Claude Code has an Agent tool with `subagent_type`. When unsure, ask the user once.

If the harness isn't listed, read `generic.md`. If the harness can't spawn subagents at all (for example the consumer chat apps), don't delegate. Do the work directly, keep the routing rules in mind, and skip the routing line.

## Settings

Edit these values to fit your plan and habits.

```
approval_required_tiers: [frontier]
recommended_main_tier: strong
max_parallel_agents: 5
routing_log: false
```

- `approval_required_tiers`: any tier listed here runs only after the user says yes in the chat (section 3a). Default is `[frontier]`. Add `strong` to gate it too, or use `[]` to gate nothing.
- `recommended_main_tier`: a recommendation only. The skill can't change the main model. It is the tier the user should pick for the chat, because the main thread makes the routing decisions and does the final check. It stays `strong` so the main thread can judge briefs and results, and so a cost-capped harness such as Copilot can still delegate `strong` parts.
- `max_parallel_agents`: the most agents to run at once.
- `routing_log`: when `true`, the skill appends one row per agent to `_routing-log.md` in the working folder, with these columns: date | task | part | tier | effort | outcome. The outcome is `ok`, `escalated` or `failed`. Default is `false`.

**Fallback rule:** if a model value is rejected or unavailable on the user's plan or harness, use the nearest available tier and say so once in the reply. Don't retry the rejected value.

## 1. The main thread directs the work and doesn't do it, unless the platform file says otherwise

On Copilot, for example, frontier work runs in the main chat after approval (see its platform file). The main thread runs on whatever model the user picked for the chat, which is usually the most expensive model in play. It keeps only these jobs:
- Talking to the user: questions, decisions and the final answer.
- Breaking the task into parts, picking a tier for each part and writing the briefs.
- Combining the results, doing the final check, and publishing or sending anything.
- Conversational replies and single quick steps, such as one lookup, one short edit or a reply from what's already in context. Every agent has a fixed cost: it starts cold, it needs a brief, and its result has to be read. When a step costs less than that, do it in the main thread.

Everything else goes to a subagent.

## 2. How to spawn

The exact call differs by harness. Follow the platform file from Step 0. These rules hold everywhere:

- If the preset agents are installed, use them: `router-scout` for `fast` work, `router-builder` for `standard` work, `router-architect` for `strong` work, `router-reviewer` for `strong` review work and `router-deep-thinker` for `frontier` work. When installed as a plugin, their names may carry a prefix. Otherwise spawn a general-purpose subagent, and use a read-only search or planning agent where the harness offers one.
- Choose the model for every spawn. An agent without a model inherits the main thread's model, which defeats the point of this skill.
- Set the effort level from the tier table when the harness lets you. On harnesses that fix the model in the agent definition and don't allow it per call, route by calling the preset agent for the tier.
- Never run a gated tier by any route without approval, including a preset agent whose default model is gated. If `strong` is gated, call `router-architect` or `router-reviewer` only with an approved lower model, or ask first. On platforms where the model is fixed per definition (Gemini CLI, Cursor, Copilot), ask the user first instead.
- Never route work through a spawn mode that ignores the model you chose, such as a fork of the main thread that always runs on the parent's model. On Claude Code this is `subagent_type: "fork"`; see the platform file.
- Launch independent agents together so they run in parallel, up to `max_parallel_agents` at once. One agent per file is fine for bulk jobs, in batches of that size. Leave them in the background unless the very next step needs the result.
- Subagents don't spawn their own subagents. The main thread owns all routing.
- Never guess what a running agent will return, and never announce its result early. Wait for its notification. The user doesn't see agent reports, so pass on what matters to them.

## 3. Tiers

| Tier | Effort | Use for |
|---|---|---|
| `fast` | low | Mechanical, rule-bound work whose output can be checked at a glance |
| `standard` | medium | Standard production work with a clear spec |
| `strong` | high | Judgment, ambiguity, high stakes and reviewing other agents' work (`router-architect` does the work, `router-reviewer` reviews) |
| `frontier` | high | The hardest few percent of problems, subject to the approval setting |

**fast**
- Pull fields out of documents, PDFs, spreadsheets or emails into a table
- Convert files to Markdown, or reformat, rename, dedupe, count and sort
- Run web searches and return each URL with a one-line finding, and check links
- Summarize a single document, or list a folder and say what each file holds
- Grep a codebase for usages of a function, and list the matches with file paths
- Short translations and tagging or labeling records

**standard**
- Implement a feature, endpoint or script from a written spec, and write its tests
- Build documents, spreadsheets and slide decks from an agreed outline
- Research synthesis across roughly 5 to 15 sources
- Compare vendors, tools or options against criteria that are already set
- Routine debugging, data cleaning, standard queries and charts
- Runbooks, emails and memos in a known format

**strong**
- Architecture and design decisions, and requirements that are unclear or conflicting
- Compliance or regulatory gap judgments and security reviews
- Executive and board narratives, positions and negotiation stances
- Refactors that span many files
- Root-cause analysis of an incident or a failure with no obvious cause
- Independent review of `fast` or `standard` output before high-stakes work reaches the user

**frontier**
- New strategy or design problems with many interlocking constraints
- A problem that a `strong` agent tried and got stuck on
- The final independent challenge of a high-stakes pack or design

Note: some vendors restrict their top model in certain domains, such as cybersecurity work. Where the platform file says so, `strong` is the top tier for that work.

If you can't decide between two tiers, pick the lower one when the output is cheap to check. Pick the higher one when the output goes to executives, customers, a regulator or a vendor.

If the main thread itself runs on a `standard` or `fast` model, the table still applies. Send `strong` parts up to a `strong` agent instead of doing them in the main thread, and follow section 3a for any tier in `approval_required_tiers`.

## 3a. Approval for gated tiers

Every tier in `approval_required_tiers` (default: `frontier`) needs the user's yes before it runs.
- Ask with the harness's structured question tool if it has one (on Claude Code, AskUserQuestion). If it doesn't, ask in plain chat. Name each part that might need the tier and say why a lower tier may fall short. Offer two options: run on the gated tier, or use the tier below it. Put every part of the task that might need the gated tier into that one question.
- A yes covers only the parts named in that question. Any other part needs its own yes.
- If the user isn't there to answer, for example in a scheduled run or when the question goes unanswered, and the part has not been tried yet (the gated tier was proposed up front), run the part on the tier below. In the final reply, name it as a part that could be re-run on the gated tier if the user wants.

## 4. Patterns

- **Plan high, build low, check fresh.** A `strong` agent or the main thread settles the plan and the decisions. `standard` and `fast` agents do the building. Then a reviewer that took no part in the build checks it: `standard` for routine work, `strong` for high stakes.
- **Scout, then think.** `fast` agents read the bulk material (long PDFs, many files, search results) and return compact evidence: facts, short quotes with sources, and file paths. A higher tier or the main thread reasons over that evidence. This keeps the expensive context small.
- **Separate outputs.** Agents running in parallel each write to their own files, so none overwrites another's work.

Worked examples: `references/decomposition-examples.md`.

## 5. Escalation

- If a result is wrong, thin or off-brief, re-run that part once, one tier higher, with a tighter brief that says what went wrong. Don't retry on the same tier, and don't skip a tier.
- If the next tier up is in `approval_required_tiers`, don't move there on your own. Stop, tell the user what blocked the part, and ask whether to use the gated tier or take another approach.
- If a part already failed on the tier below and the user declines the gated tier or doesn't answer, stop that part. Report it as blocked, with what the lower tier found, and don't re-run it on the same tier.
- If an agent on the highest permitted tier fails, stop and tell the user what blocked it.
- If a part turns out easier than expected, route the next similar part one tier lower.

## 6. Briefs

Agents can't see this chat, and cheaper models need tighter briefs. Every brief states:
1. **Goal:** what the agent must produce and what "done" means.
2. **Inputs:** exact file paths, URLs or data.
3. **Decisions already made**, plus the user's conventions from memory, project instructions or this chat that apply to this part.
4. **Skills to load**, if any.
5. **Output:** the exact format and save path (reviews return inline). The agent returns a summary of about 300 words at most, never the full content.
6. **Limits:** no subagents, no messages to the user, and no publishing or sending anything outside the workspace.

Fill-in templates per tier: `references/brief-templates.md`.

## 7. Context and compaction

The agent can't type `/compact` or any other slash command. The harness may compact the chat by itself when the context fills up, and the user can run `/compact` or the equivalent themselves wherever their app offers it. Instead, this skill does three things:
- Bulk reading goes to agents, and only their short summaries come back. The main thread never pastes whole documents into the chat.
- In long work, write a checkpoint file called `_state.md` at each milestone. Save it in the working folder. It records the goal, the decisions, what's done, what's next and the file paths. If the chat gets compacted, nothing is lost.
- When a long chat moves into a new phase, tell the user in one line: "Good point to compact or start a fresh chat. State saved to <path>."

## 8. Routing line

End the final reply with one line saying where the work went, for example: `Routing: 4× fast (extraction), 2× standard (build), 1× strong (review).` Model names may be appended in parentheses, for example `1× strong (review, <model name>)`. If nothing was delegated, skip the routing line.

When `routing_log` is `true`, write the log rows before the final reply.

## 9. Keeping this skill current

If a chat shows that a tier keeps failing or keeps doing more than a task type needs, propose an update to the tier table to the user. Model names, tiers and plan availability change, so check the platform file's mapping against what the harness currently offers. When a routing log exists, read it before proposing tier-table changes and cite the rows that support the change. When installed as a plugin, edits to this file are lost on update. Keep custom tables in a manual install.
