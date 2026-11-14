# Decomposition examples

Five worked examples of splitting a task into routed parts. Tiers and effort follow the table in SKILL.md section 3. Each tier maps to a model through the platform file (`references/platforms/<id>.md`). Preset agents: `router-scout` (`fast`), `router-builder` (`standard`), `router-architect` (`strong`, does the work), `router-reviewer` (`strong`, reviews), `router-deep-thinker` (`frontier`). Route design, outline, storyline and root-cause parts to `router-architect`, and review parts to `router-reviewer`. Adjust the counts to the actual task.

## 1. Research report from about 20 web sources

Task: write a report that answers a research question using about 20 web sources.

| Part | Tier | Effort | Runs | Why |
|---|---|---|---|---|
| Find and read sources 1-5, 6-10, 11-15, 16-20 | `fast` | low | Parallel (4 agents) | Mechanical reading. Each returns URL, short quotes and a one-line finding. |
| Check that links resolve and quotes match | `fast` | low | After all readers | Cheap to verify at a glance. |
| Outline and key claims from the evidence (`router-architect`) | `strong` | high | After the link check | Weighing conflicting sources is judgment. |
| Draft the report from the outline | `standard` | medium | After the outline | Clear spec, known format. |
| Fresh review for unsupported claims (`router-reviewer`) | `strong` | high | After the draft | The reviewer took no part in the build. |

Main thread keeps: the research question, scope decisions, the final read and the reply.

`Routing: 5× fast (source reading, link check), 2× strong (outline, review), 1× standard (draft).`

## 2. Feature built in an existing codebase

Task: add a feature to an existing codebase, with tests.

| Part | Tier | Effort | Runs | Why |
|---|---|---|---|---|
| Grep for related code, list files and call sites | `fast` | low | Parallel (2 agents: source, tests) | Mechanical search that returns paths. |
| Design: where the change goes, interfaces, edge cases (`router-architect`) | `strong` | high | After the searches | Design decisions in code that already exists. |
| Implement the feature | `standard` | medium | After the design | Clear spec. |
| Write tests | `standard` | medium | Parallel with the implementation, on separate files | The design settles the interfaces, so the tests don't need the code. |
| Review the diff against the design (`router-reviewer`) | `strong` | high | After build and tests | Fresh reviewer, and the change touches existing behavior. |

Main thread keeps: the feature goal, approval of the design, the final test run and the reply.

`Routing: 2× fast (code search), 2× strong (design, review), 2× standard (implementation, tests).`

## 3. Batch job over 50 PDFs

Task: extract the same set of fields from 50 PDFs into one table, and flag problem files.

| Part | Tier | Effort | Runs | Why |
|---|---|---|---|---|
| Extract fields from each PDF, 5 files per agent | `fast` | low | Parallel, 10 agents in batches of `max_parallel_agents` | Fixed schema, checkable output. |
| Merge the 10 outputs, dedupe and sort | `fast` | low | After all extractors | Mechanical. |
| Spot-check 10 rows against the PDFs | `standard` | medium | After the merge | Catches systematic misreads. |
| Re-run failed or "not found" files | `standard` | medium | After the spot-check, only if needed | One tier up from the first attempt (SKILL.md section 5). |

Main thread keeps: the schema, the decision on which problem files matter, and the summary for the user.

`Routing: 11× fast (extraction, merge), 1× standard (spot-check), plus standard re-runs if needed.`

## 4. Executive slide deck

Task: a 12-slide deck for an executive audience, built from existing documents and data.

| Part | Tier | Effort | Runs | Why |
|---|---|---|---|---|
| Pull facts, figures and quotes from the source documents | `fast` | low | Parallel (3 agents, one per source group) | Extraction with sources. |
| Storyline: message per slide, order, what to leave out (`router-architect`) | `strong` | high | After extraction | Executive narrative is judgment. |
| Build the slides from the storyline | `standard` | medium | After the storyline | Known format, agreed outline. |
| Check every number and quote against the extracted facts | `fast` | low | After the build | Mechanical comparison. |
| Review for message, tone and gaps (`router-reviewer`) | `strong` | high | After the check | Output goes to executives, so use the higher tier. |

Main thread keeps: the audience and the ask, the final read of the deck, and delivery.

`Routing: 4× fast (extraction, number check), 2× strong (storyline, review), 1× standard (build).`

## 5. Investigation of a production bug

Task: find the root cause of a production failure with no obvious cause, and propose a fix. This example uses the `frontier` tier once. It needs approval before it runs (SKILL.md section 3a).

| Part | Tier | Effort | Runs | Why |
|---|---|---|---|---|
| Collect log lines and errors around the failure window | `fast` | low | Parallel (2 agents: app logs, infrastructure logs) | Mechanical filtering with quoted lines. |
| Grep the code paths named in the errors | `fast` | low | Parallel with log collection | Returns file paths and snippets. |
| Root-cause analysis from the evidence (`router-architect`) | `strong` | high | After collection | Failure with no obvious cause. |
| Challenge the root cause when `strong` is stuck or the causes conflict (needs approval) | `frontier` | high | After the `strong` analysis, only if it fails | A problem that a `strong` agent tried and got stuck on. Ask only after the `strong` pass fails. If declined, report the part as blocked with the `strong` agent's findings. |
| Implement the fix and a regression test | `standard` | medium | After the root cause is agreed | Clear spec. |
| Review the fix against the root cause (`router-reviewer`) | `strong` | high | After the fix | Fresh reviewer. |

Main thread keeps: the incident scope, the approval question for `frontier`, the decision to ship, and the reply.

`Routing: 3× fast (logs, code search), 2× strong (analysis, review), 1× standard (fix), 1× frontier if approved (root-cause challenge).`
