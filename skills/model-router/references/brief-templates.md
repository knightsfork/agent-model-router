# Brief templates

Fill-in templates for the five roles. Each follows the six brief fields in SKILL.md section 6: Goal, Inputs, Decisions and conventions, Skills to load, Output, Limits. Replace every `<placeholder>`. Delete lines that don't apply, but keep all six fields.

Shared rules: never paste secrets, credentials or tokens into a brief. Point to files instead, and include only the files the part needs.

## Scout (`fast`, low), preset agent `router-scout`

For reading and extraction.

```
GOAL
Read <inputs> and extract <what to extract>. Done means every item in <inputs>
has one row in the output, or a "not found" entry.

INPUTS
<exact file paths or URLs, one per line>

DECISIONS AND CONVENTIONS
- No judgment calls. Don't rank, evaluate or recommend.
- Quote exact text for every fact, with its source (file and page, or URL).
- If a field is missing, write "not found". Never guess or infer.
- <naming, date format, units or other conventions>

SKILLS TO LOAD
<skill names, or "none">

OUTPUT
Save to <path>. Format: <table with columns A | B | C | Source>, or JSON with
keys <key1>, <key2>, <key3>.
Example row:
<one fully filled example row>
Return a summary of 300 words or less: rows written, items marked "not found",
and any file you couldn't open.

LIMITS
No subagents. No messages to the user. Don't publish or send anything outside
the workspace. Don't edit the input files.
```

A `fast` model follows formats literally, so show one filled example row and name every column or key. Keep the task to one kind of reading, one input type and one output shape. Say what to do when data is missing, or it will fill the gap with a plausible guess. Check a sample of rows against the sources when the result comes back.

## Builder (`standard`, medium), preset agent `router-builder`

For building from a spec.

```
GOAL
Build <deliverable> that meets the acceptance criteria below.

INPUTS
- Spec: <path or pasted text>
- Reference material: <paths>

ACCEPTANCE CRITERIA
1. <testable criterion>
2. <testable criterion>
3. <testable criterion>

DECISIONS AND CONVENTIONS
- <decision already made, with the reason if it isn't obvious>
- <style, naming, framework or format conventions>
- Don't reopen these decisions. If one blocks the work, stop and say so.

FILES
- May create or edit: <paths or patterns>
- Must not touch: <paths or patterns>

SKILLS TO LOAD
<skill names, or "none">

OUTPUT
Save to <path>. Before returning, run <test command or named checks> and fix
what fails. Return a summary of 300 words or less: files changed, the check
results (pass or fail, with the output of any failure), and anything in the
spec you couldn't meet.

LIMITS
No subagents. No messages to the user. Don't publish or send anything outside
the workspace. Don't add features beyond the spec.
```

A `standard` model does well with a clear spec and testable criteria, and poorly with open questions. Settle the decisions before the brief goes out, and list them. Name the files it may and may not touch so parallel builders don't collide. Name the exact check to run, because "make sure it works" gets a shallow check.

## Architect (`strong`, high), preset agent `router-architect`

For judgment-heavy work that produces something: design decisions, root-cause analysis, multi-file refactors, outlines, storylines and high-stakes writing.

```
GOAL
Produce <deliverable> that meets the acceptance criteria below. Where the
inputs leave a judgment call, make it and state your reasoning in one or two
lines.

INPUTS
- Spec or problem statement: <path or pasted text>
- Evidence and reference material: <paths, for example scout output>

ACCEPTANCE CRITERIA
1. <testable criterion>
2. <testable criterion>
3. <testable criterion>

DECISIONS AND CONVENTIONS
- <decision already made, with the reason if it isn't obvious>
- <style, naming, framework or format conventions>
- Don't reopen these decisions. If one blocks the work, stop and say so.

FILES
- May create or edit: <paths or patterns>
- Must not touch: <paths or patterns>

SKILLS TO LOAD
<skill names, or "none">

OUTPUT
Save to <path>. Before returning, run <test command or named checks> and fix
what fails. Return a summary of 300 words or less: what you decided and why,
what you produced and where, check results and open risks.

LIMITS
No subagents. No messages to the user. Don't publish or send anything outside
the workspace.
```

A `strong` model can handle ambiguity, so say which calls are open for it to make and which are already settled. Give it the evidence compressed, since `fast` scouts should have done the reading. Ask for the reasoning behind each judgment call in a line or two, so the main thread can check it. Send the result to `router-reviewer` before it reaches the user when the stakes are high.

## Reviewer (`strong`, high), preset agent `router-reviewer`

A fresh reviewer that took no part in the build.

```
GOAL
Review <deliverable> against the goal and acceptance criteria below. You took
no part in building it. Report problems and don't fix them.

GOAL OF THE WORK
<one or two sentences>

ACCEPTANCE CRITERIA
1. <criterion>
2. <criterion>
3. <criterion>

INPUTS
- Deliverable: <paths>
- Spec or source material: <paths>
- Build agent's summary: <paste it, or "none">

DECISIONS AND CONVENTIONS
- <decisions already made. Don't flag these as issues.>
- <standards the work must meet>

SKILLS TO LOAD
<skill names, or "none">

OUTPUT
Return the report inline, in 300 words or less (or the limit set in the brief). Don't save it to a file. Use this structure:
1. Verdict: pass, pass with fixes, or fail, in one sentence.
2. Criteria check: each criterion marked met, partly met or not met, with a
   one-line reason.
3. Must fix: issues that break a criterion or the goal, ranked by severity.
   Each has the file and line, or the section, what's wrong and why it matters.
4. Nice to have: improvements that don't block acceptance, same format.

LIMITS
Don't rewrite or edit the work. No subagents. No messages to the user. Don't
publish or send anything outside the workspace.
```

A review succeeds when the reviewer starts cold, has the goal and criteria and not the builder's reasoning, and has to point to a file and line or a section for every issue. Don't tell it the work is probably fine. Keep "must fix" strict: if the issue doesn't break a criterion, it goes under "nice to have".

## Deep thinker (`frontier`, gated), preset agent `router-deep-thinker`

Use only after the user has approved the tier for this part (SKILL.md section 3a).

```
APPROVAL
<quote the user's yes and the question it answered, from this chat>

GOAL
Decide <the decision needed>. Done means a recommendation with the options
considered and the trade-offs of each.

PROBLEM STATEMENT
<the problem in a few sentences, with what's at stake>

WHAT LOWER TIERS TRIED
- <agent and tier>: <what it did and what it returned>
- Why it fell short: <specific gap, conflict or error>

INPUTS
<paths to evidence, prior outputs and source material>

CONSTRAINTS
- <hard constraints: budget, time, policy, technology, people>
- <soft preferences, marked as preferences>

DECISIONS AND CONVENTIONS
<decisions already made that this one must fit with>

SKILLS TO LOAD
<skill names, or "none">

OUTPUT
Return inline, with no file saved:
1. The decision, restated in one sentence.
2. Two to four options. For each: how it works, what it costs, what it risks,
   and when it's the right choice.
3. A recommendation, with the reasoning and what would change it.
4. Open questions that only the user can answer.
Return a summary of 300 words or less.

LIMITS
No subagents. No messages to the user. Don't publish or send anything outside
the workspace.
```

The `frontier` tier is for the hardest problems, so a brief for it succeeds by being a sharp decision problem and not a task list. State what's already been tried and why it failed, so the agent doesn't repeat it. Give the real constraints, and mark which are fixed. Ask for options with trade-offs and a recommendation, not a finished deliverable. Hand the evidence over compressed, since `fast` scouts should have done the reading.
