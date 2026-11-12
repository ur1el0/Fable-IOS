# Repository Contribution Guidance

## Commit Milestones

- Organize each pull request as a sequence of focused commits, with each commit representing one reviewable milestone.
- Separate backend or app logic, tests, UI or design, and documentation, configuration, or deployment work into distinct commits when they can be understood independently.
- Keep tests separate from implementation logic when practical, and order dependent commits so the complete pull request forms a coherent change.
- Use clear Conventional Commit messages with a relevant scope, such as `fix(catalog): use live provider data`, `test(catalog): cover provider responses`, or `style(reader): refine chapter layout`.
- Keep tightly coupled changes together when splitting them would make a commit misleading or impossible to review; do not split solely to increase the commit count.
- Before merging, verify the final pull request state with the relevant local checks and CI.
