<!-- Thanks for contributing! Keep PRs focused and describe how you verified them. -->

## What & why

<!-- What does this change, and why? Link issues with "Closes #123". -->

## How I verified

- [ ] `make lint` clean
- [ ] `make test` green
- [ ] Manually checked the affected screen/flow (note device/OS below)

<!-- Device/OS tested, before/after screenshots or a recording if it's UI. -->

## Checklist

- [ ] SwiftUI only; design-system components (`Color.sv.*` / `SV*`) — no ad-hoc styling
- [ ] New pure logic lives in `Math/` with unit tests
- [ ] No hardcoded model constants (read from the manifest)
- [ ] Docs / WORKLOG updated if behavior or architecture changed
- [ ] `project.yml` edited (not the generated `.xcodeproj`) for any file add/remove
