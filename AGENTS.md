# EDITH Project Instructions

## Project goal

Transform the existing Noa Flutter application into an original AR assistant
interface named EDITH.

The initial phase is a visual and structural reskin only.

## Current phase

Phase 1: EDITH interface reskin and hardware-independent simulator.

## Rules

- Do not remove working Noa functionality.
- Do not modify AI provider behavior unless specifically requested.
- Do not modify authentication, networking, Bluetooth, camera, microphone,
  firmware update, or device protocol code during the initial reskin.
- Do not expose API keys, secrets, tokens, or environment variables.
- Do not commit the .env file.
- Do not make large unrelated refactors.
- Preserve existing application behavior.
- Keep changes small, reviewable, and reversible.
- Run formatting, static analysis, and tests after changes.
- Explain any existing build failures separately from failures caused by edits.
- Prefer reusable Flutter theme tokens over hardcoded visual values.
- Keep hardware integrations behind interfaces so a simulator can replace them.
- Use original EDITH graphics and icons. Do not copy movie artwork or logos.

## Architecture goals

Separate these layers:

1. EDITH presentation and theme
2. Application state
3. AI services
4. Brilliant device services
5. Simulated device services

## Visual direction

- Name: EDITH
- Style: clean futuristic interface
- Background: near-black
- Primary accent: cyan
- Secondary accent: cool blue
- Status success: green
- Status warning: amber
- High contrast and readable typography
- Minimal animations
- Designed for a small circular AR display
- Avoid excessive gradients, glow, and visual clutter

## Development requirements

Before editing:

1. Inspect the repository.
2. Identify app entry points and state management.
3. Identify every visible Noa branding reference.
4. Identify all device-specific dependencies.
5. Run the existing analysis and tests.
6. Report the proposed changed files.

After editing:

1. Run dart format.
2. Run flutter analyze.
3. Run available tests.
4. Report changed files.
5. Report remaining warnings and errors.