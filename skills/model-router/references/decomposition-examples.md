# Decomposition examples

Five worked examples of splitting a task into routed parts. Tiers and effort follow the table in SKILL.md section 3. Adjust the counts to the actual task.

## 1. Research report from about 20 web sources

Task: write a report that answers a research question using about 20 web sources.

| Part | Tier | Effort | Runs | Why |
|---|---|---|---|---|
| Find and read sources 1-5, 6-10, 11-15, 16-20 | Haiku | low | Parallel (4 agents) | Mechanical reading. Each returns URL, short quotes and a one-line finding. |
| Check that links resolve and quotes match | Haiku | low | After all readers | Cheap to verify at a glance. |
| Outline and key claims from the evidence | Opus | high | After the link check | Weighing conflicting sources is judgment. |
| Draft the report from the outline | Sonnet | medium | After the outline | Clear spec, known format. |
| Fresh review for unsupported claims | Opus | high | After the draft | The reviewer took no part in the build. |

Main thread keeps: the research question, scope decisions, the final read and the reply.

`Routing: 5× Haiku (source reading, link check), 2× Opus (outline, review), 1× Sonnet (draft).`

## 2. Feature built in an existing codebase

Task: add a feature to an existing codebase, with tests.

| Part | Tier | Effort | Runs | Why |
|---|---|---|---|---|
| Grep for related code, list files and call sites | Haiku | low | Parallel (2 agents: source, tests) | Mechanical search that returns paths. |
| Design: where the change goes, interfaces, edge cases | Opus | high | After the searches | Design decisions in code that already exists. |
| Implement the feature | Sonnet | medium | After the design | Clear spec. |
| Write tests | Sonnet | medium | Parallel with the implementation, on separate files | The design settles the interfaces, so the tests don't need the code. |
| Review the diff against the design | Opus | high | After build and tests | Fresh reviewer, and the change touches existing behavior. |

Main thread keeps: the feature goal, approval of the design, the final test run and the reply.

`Routing: 2× Haiku (code search), 2× Opus (design, review), 2× Sonnet (implementation, tests).`

## 3. Batch job over 50 PDFs

Task: extract the same set of fields from 50 PDFs into one table, and flag problem files.

| Part | Tier | Effort | Runs | Why |
|---|---|---|---|---|
| Extract fields from each PDF, 5 files per agent | Haiku | low | Parallel, 10 agents in batches of `max_parallel_agents` | Fixed schema, checkable output. |
| Merge the 10 outputs, dedupe and sort | Haiku | low | After all extractors | Mechanical. |
| Spot-check 10 rows against the PDFs | Sonnet | medium | After the merge | Catches systematic misreads. |
| Re-run failed or "not found" files | Sonnet | medium | After the spot-check, only if needed | One tier up from the first attempt (SKILL.md section 5). |

Main thread keeps: the schema, the decision on which problem files matter, and the summary for the user.

`Routing: 11× Haiku (extraction, merge), 1× Sonnet (spot-check), plus Sonnet re-runs if needed.`

## 4. Executive slide deck

Task: a 12-slide deck for an executive audience, built from existing documents and data.

| Part | Tier | Effort | Runs | Why |
|---|---|---|---|---|
| Pull facts, figures and quotes from the source documents | Haiku | low | Parallel (3 agents, one per source group) | Extraction with sources. |
| Storyline: message per slide, order, what to leave out | Opus | high | After extraction | Executive narrative is judgment. |
| Build the slides from the storyline | Sonnet | medium | After the storyline | Known format, agreed outline. |
| Check every number and quote against the extracted facts | Haiku | low | After the build | Mechanical comparison. |
| Review for message, tone and gaps | Opus | high | After the check | Output goes to executives, so use the higher tier. |

Main thread keeps: the audience and the ask, the final read of the deck, and delivery.

`Routing: 4× Haiku (extraction, number check), 2× Opus (storyline, review), 1× Sonnet (build).`

## 5. Investigation of a production bug

Task: find the root cause of a production failure with no obvious cause, and propose a fix. This example uses Fable once. It needs approval before it runs (SKILL.md section 3a).

| Part | Tier | Effort | Runs | Why |
|---|---|---|---|---|
| Collect log lines and errors around the failure window | Haiku | low | Parallel (2 agents: app logs, infrastructure logs) | Mechanical filtering with quoted lines. |
| Grep the code paths named in the errors | Haiku | low | Parallel with log collection | Returns file paths and snippets. |
| Root-cause analysis from the evidence | Opus | high | After collection | Failure with no obvious cause. |
| Challenge the root cause when Opus is stuck or the causes conflict (needs approval) | Fable | high | After the Opus analysis, only if it fails | A problem that an Opus agent tried and got stuck on. Ask only after the Opus pass fails. If declined, report the part as blocked with Opus's findings. |
| Implement the fix and a regression test | Sonnet | medium | After the root cause is agreed | Clear spec. |
| Review the fix against the root cause | Opus | high | After the fix | Fresh reviewer. |

Main thread keeps: the incident scope, the approval question for Fable, the decision to ship, and the reply.

`Routing: 3× Haiku (logs, code search), 2× Opus (analysis, review), 1× Sonnet (fix), 1× Fable if approved (root-cause challenge).`
