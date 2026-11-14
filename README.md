# model-router

`model-router` is a Claude skill that makes the main chat model act as an orchestrator. It sends most of the work to subagents and runs each one on the cheapest model that will do its part well. Top-tier models stay off simple work such as extraction, reformatting and searching, so the skill aims to stretch your usage credit while keeping the final result's quality.

## How it works

The main chat model directs the work. It talks to you, splits the task into parts, picks a tier for each part, writes a brief for each agent, combines the results and does the final check. Quick single steps stay in the main thread, because spawning an agent has a fixed cost.

Each part goes to one of four tiers:

| Tier | `model` | `effort` | Use for |
|---|---|---|---|
| Haiku | `haiku` | `low` | Mechanical work: extraction, conversion, searches, grep, summaries of one document |
| Sonnet | `sonnet` | `medium` | Standard production work with a clear spec: features from a spec, documents from an outline, research synthesis, routine debugging |
| Opus | `opus` | `high` | Judgment and high stakes: architecture, compliance gap judgments, security reviews, executive narratives. Routine reviews of other agents' work go to Sonnet and high-stakes reviews to Opus |
| Fable | `fable` | `high` or `xhigh` | The hardest few percent of problems. Off by default until you approve it in the chat |

The skill also covers common patterns (plan high, build low, check fresh; scout then think; separate outputs), one-tier-up escalation, a brief template for agents, `_state.md` checkpoints for long work, and a closing routing line that says where the work went.

The skill loads automatically on any task with more than one step. You don't need to name it.

## What's included

```
.claude-plugin/
  plugin.json                  plugin manifest
  marketplace.json             lets this repo act as its own plugin marketplace
skills/model-router/
  SKILL.md                     the routing skill
  references/
    brief-templates.md         fill-in briefs for scout, builder, reviewer and deep thinker
    decomposition-examples.md  five worked examples of splitting a task across tiers
agents/
  router-scout.md              Haiku, low effort, read-only tools
  router-builder.md            Sonnet, medium effort, can edit files and run checks
  router-reviewer.md           Opus, high effort, reviews and reports, never rewrites
```

The three preset agents have their model, effort and tools already set, so the skill can call them by name. There is no preset Fable agent, because Fable sits behind the approval gate by default.

## Install as a Claude Code plugin (recommended)

This installs the skill and the three preset agents together. In Claude Code 2.1.275 or later, run this in one step:

```
/plugin install model-router --marketplace knightsfork/claude-model-router
```

Or from a terminal:

```
claude plugin install model-router --marketplace knightsfork/claude-model-router
```

In older versions, add the marketplace first:

```
/plugin marketplace add knightsfork/claude-model-router
/plugin install model-router@model-router
```

## Install manually for Claude Code

For all your projects:

```
git clone https://github.com/knightsfork/claude-model-router.git model-router-repo
mkdir -p ~/.claude/skills ~/.claude/agents
cp -r model-router-repo/skills/model-router ~/.claude/skills/
cp model-router-repo/agents/*.md ~/.claude/agents/
```

For one repository only:

```
git clone https://github.com/knightsfork/claude-model-router.git model-router-repo
mkdir -p .claude/skills .claude/agents
cp -r model-router-repo/skills/model-router .claude/skills/
cp model-router-repo/agents/*.md .claude/agents/
```

Start a new session afterward so the skill and agents are picked up.

## Install for the Claude apps

1. Zip the `model-router` folder (`skills/model-router`) so the zip contains the folder with `SKILL.md` inside it.
2. In Claude's skill settings, upload the zip as a custom skill.
3. Make sure the skill is turned on.

The apps install only the skill. The preset agents are a Claude Code feature, and without them the skill uses general-purpose agents with `model` set on each call. Custom skills and subagent support depend on your plan and app version.

## Configuration

Open `skills/model-router/SKILL.md` and edit the Settings block near the top:

```
approval_required_tiers: [fable]
recommended_main_model: opus
max_parallel_agents: 5
routing_log: false
```

- `approval_required_tiers`: tiers that run only after you say yes in the chat. Claude asks with AskUserQuestion, names the parts, and a yes covers only those parts. If you are away, a part that hasn't been tried yet runs on the tier below and the reply flags it. If a part already failed on the tier below and you decline or don't answer, the part is stopped and reported as blocked with what the lower tier found. Default is `[fable]`. Use `[]` for no gating.
- `recommended_main_model`: the model you should select for the chat. The skill can't change the main model, so this is a recommendation only.
- `max_parallel_agents`: the most agents to run at once.
- `routing_log`: set it to `true` and the skill appends one row per agent to `_routing-log.md` in the working folder, recording the date, task, part, tier, effort and outcome. When the skill proposes tier-table changes, it reads this log and cites the rows that support them. Off by default.

If a model value is rejected or unavailable on your plan or harness, the skill uses the nearest available tier and says so once.

When installed as a plugin, the skill lives in Claude Code's plugin cache and is replaced on update. If you want custom settings or tier tables, use the manual install and edit your own copy.

## Limitations

- **Forks ignore `model`.** Fork subagents always run on the main thread's model, so the skill never routes through them. It sets `model` on every call instead.
- **No self-run `/compact`.** Claude can't type slash commands. The skill writes `_state.md` checkpoints and keeps agent summaries short, and you can run `/compact` yourself where your app offers it.
- **Model availability varies by plan.** Some tiers, including Fable, may not be available to you. The skill falls back to the nearest available tier.
- **Agents cost something.** Each agent starts cold, needs a brief and returns a result that has to be read. For tiny tasks, spawning agents can cost more than it saves. The skill keeps single quick steps in the main thread, but it will not always judge this correctly.
- **Savings are not guaranteed.** Tier choices are judgment calls. A part sent too low is re-run one tier up, which costs extra.

## Contributing

Issues and pull requests are welcome. Useful contributions include tier table corrections based on real runs, new generic examples, and notes on how different harnesses handle the `model` and `effort` parameters. Keep the skill free of personal, employer or domain-specific references, and keep the prose plain and in American English. Update `CHANGELOG.md` with any change to the skill.

## License

Released under the [MIT License](LICENSE). Copyright (c) 2026 Hatem Mohamed.
