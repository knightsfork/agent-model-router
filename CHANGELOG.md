# Changelog

## 1.0.0 - 2026-11-14

- Initial public release of the `model-router` skill.
- Orchestrator pattern with four tiers (Haiku, Sonnet, Opus, Fable), effort settings and generic examples.
- Settings block: `approval_required_tiers`, `recommended_main_model`, `max_parallel_agents`.
- Approval flow for gated tiers, escalation rules, brief template, `_state.md` checkpoints and routing line.
- Fallback rule for model values that are rejected or unavailable.
- Optional `routing_log` setting that records each routing decision in `_routing-log.md` for tuning the tier table.
- Reference files: brief templates per tier and five worked decomposition examples.
- Preset agents `router-scout` (Haiku), `router-builder` (Sonnet) and `router-reviewer` (Opus).
- Claude Code plugin packaging: `plugin.json`, a self-hosted `marketplace.json` and an icon.
