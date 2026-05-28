# File 09 - Rollout And Deployment

Goal: ship Rex Brain safely without breaking working chat, voice, or finances.

Status: `00.10` implementation complete. Rollout is now controlled by both the existing master kill switch, `REX_BRAIN_ROUTING_ENABLED`, and a staged rollout gate, `REX_BRAIN_ROLLOUT_STAGE`.

## Phase 1 - Env Templates

Updated:

- `services/rex-api/.env.example`
- `deploy/templates/rex-api.env.example`
- `services/rex-api/mobile.env.example`

New setting:

```env
REX_BRAIN_ROLLOUT_STAGE=disabled
```

Accepted stages:

- `disabled`
- `logging_only`
- `fast_contextual`
- `analytical`
- `strategic_reflective`
- `deep_think_ui`

Acceptance:

- New settings are documented in env templates.

## Phase 2 - Backward Compatibility

Implemented:

- `GROK_MODEL` remains the fallback model for all profiles.
- If `REX_BRAIN_ROUTING_ENABLED=false`, model routing remains disabled regardless of rollout stage.
- If `REX_BRAIN_ROLLOUT_STAGE=logging_only`, planning/observability can run while live model/prompt routing stays disabled.

Acceptance:

- Existing VPS env still works.

## Phase 3 - Disabled-By-Default Release

Implemented default:

```env
REX_BRAIN_ROUTING_ENABLED=false
REX_BRAIN_ROLLOUT_STAGE=disabled
```

Acceptance:

- No user-visible behavior change unless the VPS explicitly enables routing.

## Phase 4 - Debug-Only Enablement

Current rule:

- Keep `REX_BRAIN_DEBUG_ENABLED=false` in production unless actively debugging.
- Debug output must remain metadata-only and must not expose prompt text, raw messages, raw memory, or raw financial rows.

Acceptance:

- Release UI does not expose internals.

## Phase 5 - VPS Restart Flow

Use only:

```sh
cd /opt/clarity/current
./scripts/vps_restart_rex_api.sh
```

Acceptance:

- Do not restart legacy `rex-backend` for this project.

## Phase 6 - Phone Release Flow

Use from the Mac/iPhone build machine:

```sh
./scripts/mobile_release_run.sh
```

Acceptance:

- Release build installs to connected iPhone.

## Phase 7 - Staged Enablement

Production order:

1. `disabled` with `REX_BRAIN_ROUTING_ENABLED=false`.
2. `logging_only` with `REX_BRAIN_ROUTING_ENABLED=true` for metadata-only validation.
3. `fast_contextual` for low-risk fast/contextual routing.
4. `analytical` for financial and logical analysis routing.
5. `strategic_reflective` for strategic and reflective routes.
6. `deep_think_ui` for full backend routing plus Deep Think UX validation.

Acceptance:

- Each stage has an immediate rollback path.
- Tests verify stages block deeper layers until explicitly enabled.

## Phase 8 - Rollback Plan

Rollback env:

```env
REX_BRAIN_ROUTING_ENABLED=false
REX_BRAIN_ROLLOUT_STAGE=disabled
```

Then restart:

```sh
cd /opt/clarity/current
./scripts/vps_restart_rex_api.sh
```

Acceptance:

- Rollback does not require a mobile reinstall when possible.

## Implementation Notes

Code gates live model/prompt routing in `RexModelRouter`:

- `logging_only` returns a disabled route with a rollout reason.
- `fast_contextual` allows only Layer 0/1.
- `analytical` allows Layer 0/1/2 plus coaching.
- `strategic_reflective` and `deep_think_ui` allow all layers.

Readiness now reports the active rollout stage and the accepted stage list so VPS/mobile state can be checked before testing.
