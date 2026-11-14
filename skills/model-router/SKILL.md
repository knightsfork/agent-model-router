---
name: model-router
description: Apply automatically, without being named, at the start of any task with more than one step, to route its parts to subagents on the cheapest model that will do each part well.
---

# Model router

Delegate every part that costs more than an agent's fixed overhead, and run each subagent on the cheapest model that will do its part well. Installing this skill is the user's standing request to delegate to subagents, so don't ask for permission to spawn them.

This skill applies automatically. The user never needs to name or call it. Use it on any task with more than one step, in any chat. Section 1 says which parts stay in the main thread.

## Settings

Edit these values to fit your plan and habits.

```
approval_required_tiers: [fable]
recommended_main_model: opus
max_parallel_agents: 5
routing_log: false
```

- `approval_required_tiers`: any tier listed here runs only after the user says yes in the chat (section 3a). Default is `[fable]`. Add `opus` to gate it too, or use `[]` to gate nothing.
- `recommended_main_model`: a recommendation only. The skill can't change the main model. It is the model the user should pick for the chat, because the main thread makes the routing decisions and does the final check.
- `max_parallel_agents`: the most agents to run at once.
- `routing_log`: when `true`, the skill appends one row per agent to `_routing-log.md` in the working folder, with these columns: date | task | part | tier | effort | outcome. The outcome is `ok`, `escalated` or `failed`. Default is `false`.

**Fallback rule:** if a `model` value is rejected or unavailable on the user's plan or harness, use the nearest available tier and say so once in the reply. Don't retry the rejected value.

## 1. The main thread directs the work and doesn't do it

The main thread runs on whatever model the user picked for the chat, which is usually the most expensive model in play. It keeps only these jobs:
- Talking to the user: questions, decisions and the final answer.
- Breaking the task into parts, picking a tier for each part and writing the briefs.
- Combining the results, doing the final check, and publishing or sending anything.
- Conversational replies and single quick steps, such as one lookup, one short edit or a reply from what's already in context. Every agent has a fixed cost: it starts cold, it needs a brief, and its result has to be read. When a step costs less than that, do it in the main thread.

Everything else goes to a subagent.

## 2. How to spawn

- If the preset agents are installed, use them: `router-scout` for Haiku-tier reading, `router-builder` for Sonnet-tier building and `router-reviewer` for Opus-tier review. When installed as a plugin, their names may carry a `model-router:` prefix. Otherwise use the Agent tool with `subagent_type: "general-purpose"`. Use `"Explore"` for read-only searches across many files and `"Plan"` for implementation plans, where the harness offers them.
- Still set `model` and `effort` explicitly on preset agents, so a different tier can be chosen for one call when needed.
- Set `model` on every call. The Agent tool's `model` parameter takes `haiku`, `sonnet`, `opus` or `fable`. An agent without a model inherits the main thread's model, which defeats the point of this skill.
- Set `effort` from the tier table. The `effort` parameter takes `low`, `medium`, `high`, `xhigh` or `max`.
- Never run a gated tier by any route without approval, including a preset agent whose default model is gated. If `opus` is gated, call `router-reviewer` with an approved lower `model` or ask first.
- Never send routed work through `subagent_type: "fork"`. A fork always runs on the main thread's model and ignores `model`.
- Launch independent agents in one message so they run in parallel, up to `max_parallel_agents` at once. One agent per file is fine for bulk jobs, in batches of that size. Leave them in the background unless the very next step needs the result.
- Subagents don't spawn their own subagents. The main thread owns all routing.
- Never guess what a running agent will return, and never announce its result early. Wait for its notification. The user doesn't see agent reports, so pass on what matters to them.

## 3. Tiers

| Tier | `model` | `effort` | Use for |
|---|---|---|---|
| Haiku | `haiku` | `low` | Mechanical, rule-bound work whose output can be checked at a glance |
| Sonnet | `sonnet` | `medium` | Standard production work with a clear spec |
| Opus | `opus` | `high` | Judgment, ambiguity, high stakes and reviewing other agents' work |
| Fable | `fable` | `high` (`xhigh` for the hardest) | The hardest few percent of problems, subject to the approval setting |

**Haiku**
- Pull fields out of documents, PDFs, spreadsheets or emails into a table
- Convert files to Markdown, or reformat, rename, dedupe, count and sort
- Run web searches and return each URL with a one-line finding, and check links
- Summarize a single document, or list a folder and say what each file holds
- Grep a codebase for usages of a function, and list the matches with file paths
- Short translations and tagging or labeling records

**Sonnet**
- Implement a feature, endpoint or script from a written spec, and write its tests
- Build documents, spreadsheets and slide decks from an agreed outline
- Research synthesis across roughly 5 to 15 sources
- Compare vendors, tools or options against criteria that are already set
- Routine debugging, data cleaning, standard queries and charts
- Runbooks, emails and memos in a known format

**Opus**
- Architecture and design decisions, and requirements that are unclear or conflicting
- Compliance or regulatory gap judgments and security reviews
- Executive and board narratives, positions and negotiation stances
- Refactors that span many files
- Root-cause analysis of an incident or a failure with no obvious cause
- Independent review of Haiku or Sonnet output before high-stakes work reaches the user

**Fable**
- New strategy or design problems with many interlocking constraints
- A problem that an Opus agent tried and got stuck on
- The final independent challenge of a high-stakes pack or design

Note: Fable has extra safeguards for cybersecurity and biology, so Opus is the top tier for security engineering work.

If you can't decide between two tiers, pick the lower one when the output is cheap to check. Pick the higher one when the output goes to executives, customers, a regulator or a vendor.

If the main thread itself runs on Sonnet or Haiku, the table still applies. Send Opus-tier parts up to Opus instead of doing them in the main thread, and follow section 3a for any tier in `approval_required_tiers`.

## 3a. Approval for gated tiers

Every tier in `approval_required_tiers` (default: Fable) needs the user's yes before it runs.
- Ask with AskUserQuestion. If AskUserQuestion isn't available, ask in plain chat. Name each part that might need the tier and say why a lower tier may fall short. Offer two options: run on the gated tier, or use the tier below it. Put every part of the task that might need the gated tier into that one question.
- A yes covers only the parts named in that question. Any other part needs its own yes.
- If the user isn't there to answer, for example in a scheduled run or when the question goes unanswered, and the part has not been tried yet (the gated tier was proposed up front), run the part on the tier below. In the final reply, name it as a part that could be re-run on the gated tier if the user wants.

## 4. Patterns

- **Plan high, build low, check fresh.** An Opus agent or the main thread settles the plan and the decisions. Sonnet and Haiku agents do the building. Then a reviewer that took no part in the build checks it: Sonnet for routine work, Opus for high stakes.
- **Scout, then think.** Haiku agents read the bulk material (long PDFs, many files, search results) and return compact evidence: facts, short quotes with sources, and file paths. A higher tier or the main thread reasons over that evidence. This keeps the expensive context small.
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
3. **Decisions already made**, plus the user's conventions from memory, CLAUDE.md or this chat that apply to this part.
4. **Skills to load**, if any.
5. **Output:** the exact format and save path (reviews return inline). The agent returns a summary of about 300 words at most, never the full content.
6. **Limits:** no subagents, no messages to the user, and no publishing or sending anything outside the workspace.

Fill-in templates per tier: `references/brief-templates.md`.

## 7. Context and compaction

Claude can't type `/compact` or any other slash command. The app compacts the chat by itself when the context fills up, and the user can run `/compact` themselves wherever their app offers it. Instead, this skill does three things:
- Bulk reading goes to agents, and only their short summaries come back. The main thread never pastes whole documents into the chat.
- In long work, write a checkpoint file called `_state.md` at each milestone. Save it in the working folder. It records the goal, the decisions, what's done, what's next and the file paths. If the chat gets compacted, nothing is lost.
- When a long chat moves into a new phase, tell the user in one line: "Good point to compact or start a fresh chat. State saved to <path>."

## 8. Routing line

End the final reply with one line saying where the work went, for example: `Routing: 4× Haiku (extraction), 2× Sonnet (build), 1× Opus (review).` If nothing was delegated, skip the routing line.

When `routing_log` is `true`, write the log rows before the final reply.

## 9. Keeping this skill current

If a chat shows that a tier keeps failing or keeps doing more than a task type needs, propose an update to the tier table to the user. Model names, tiers and plan availability change, so check the table against what the harness currently offers. When a routing log exists, read it before proposing tier-table changes and cite the rows that support the change. When installed as a plugin, edits to this file are lost on update. Keep custom tables in a manual install.
