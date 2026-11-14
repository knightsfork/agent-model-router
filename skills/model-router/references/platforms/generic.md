# Generic platform (any harness not listed)

Use this file when your harness has no file of its own in `references/platforms/`. It tells you how to find out what the harness can do and how to map the four tiers to its models.

The model names below are examples of how to map, not a fixed list. Check the vendor's current model list for the user's plan.

## 1. Can this harness route by model?

Check, in this order:

1. **Subagents.** Does the harness let the main agent start another agent with its own context (a "subagent", "sub-agent", "task" or "worker" feature)? Look in its docs, its tool list and its slash-command help. If it has none, go to section 5.
2. **Per-agent model.** Can each subagent run on a different model from the main chat? This is usually one of two shapes:
   - **Per call:** the spawn tool or the spawn request takes a `model` value, or you can name a model in the request.
   - **Per definition:** the model is a field in an agent definition file (often Markdown with YAML frontmatter, or TOML), and a spawn only picks which definition to run.
3. **Inherited model.** If a subagent can't have its own model, it runs on the parent's model. Routing then can't save money, so work inline (section 5).

Don't guess. If the docs don't say, test it: spawn one cheap read-only subagent with a named model and ask it to state the model it runs on. If it can't tell you, treat per-call selection as unconfirmed and use preset agents (section 3).

## 2. Map the tiers to the vendor's models

Look at the vendor's model list and assign four models, from the cheapest up:

| Tier | Pick | Default effort |
|---|---|---|
| `fast` | The vendor's cheapest and fastest current model (often called mini, flash, lite or haiku-class) | low |
| `standard` | The mid-priced model that does well on code and documents | medium |
| `strong` | The vendor's strong general model, for judgment and review | high |
| `frontier` | The vendor's top model, or the strong model at its highest effort if there is no separate top model | high |

Rules:
- Pick from models the user's plan actually offers. If a tier has no model, use the nearest one up or down and say so once in the reply (SKILL.md fallback rule).
- If the vendor has only two models, map `fast` and `standard` to the cheaper one and `strong` and `frontier` to the other.
- If the harness has an effort or reasoning setting, set it per tier as in the table. If it has none, ignore effort.
- A subagent usually can't use a model that costs more than the parent's. If the parent is a cheaper model than the tier needs, do that part in the main thread if the main model is strong enough and the user agrees, or ask the user to switch the main chat to a stronger model. Otherwise tell the user the part is blocked. Mirror this when a requested `strong` preset is refused because it costs more than the parent.
- Keep the `frontier` approval gate even if `frontier` and `strong` map to the same model. The gate protects cost and effort, and the user's yes is still needed.

Tell the user the mapping you chose in one short line the first time you delegate, so they can correct it.

## 3. Models set only per agent definition

If the model can only be set in an agent definition, route by preset agent per tier:

1. Create five agent definitions: `router-scout` (`fast`), `router-builder` (`standard`), `router-architect` (`strong`, does the work), `router-reviewer` (`strong`, reviews) and `router-deep-thinker` (`frontier`).
2. In each, set the model from section 2 and the effort if the harness supports it.
3. Copy the role text for each agent from one of the adapter folders at https://github.com/knightsfork/agent-model-router/tree/main/adapters (`<platform>/agents/`; the `adapters/` folder isn't installed with the skill) and adjust the file format to match the harness.
4. Install them where the harness looks for agents (user level or project level; check its docs).
5. To route a part, call the preset agent for its tier. Never ask a spawn for a different model than the definition sets, because it may be ignored.

If the harness can't use the preset files, say so and ask the user to create the five agents. Until they exist, work inline (section 5).

## 4. Preset agents and gating

- Call presets by name. The harness may add a prefix when they come from a plugin.
- Never call `router-deep-thinker` before the user approves the `frontier` tier for that part (SKILL.md section 3a).
- Subagents must not spawn subagents. If the harness allows it, turn it off in the definitions.
- If the harness can limit tools, make `router-reviewer` and `router-deep-thinker` read-only and limit `router-scout` to reading, searching and one output file.

## 5. No subagents (or no model choice)

If the harness has no subagents, or subagents can only inherit the parent's model:

- Don't delegate. Do the work in the main thread, in the order the plan sets.
- Keep the routing rules in mind: break the task into parts, write the checks for each part, and review your own work as if you were a fresh reviewer before you reply.
- Keep `_state.md` checkpoints for long work (SKILL.md section 7).
- Skip the routing line, because nothing was delegated.
- If the user could get routing by switching harness or plan, say so once and don't repeat it.

## 6. How to change the models

Edit the mapping in this file, or the `model` field in each preset agent definition. Model names and plan availability change, so check the vendor's model list now and then.

## 7. Sources

Use the vendor's own documentation for subagents and for the model list. This file has no vendor URLs because it covers harnesses that aren't listed.

## Verified

Not run on any specific harness. It is guidance for harnesses without their own file. Please report results.
