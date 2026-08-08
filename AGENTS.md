# Agent Foundry working agreement

This repository grows reusable local-agent capabilities from real work.

## Boundaries

- `foundry/` defines repository-wide contracts, catalogs, and templates.
- `packs/` contains reusable capabilities expressed in the vocabulary of the
  software being automated.
- `examples/` contains project-specific compositions, fixtures, and lessons.
- Business vocabulary discovered in a request stays in an example until a
  smaller, generally useful mechanism can be harvested into a pack.

## Harvesting rule

When a task exposes a missing capability:

1. solve the task in its example;
2. identify the smallest application-native operation that was missing;
3. add that operation to the relevant pack only if it is useful without the
   original task's vocabulary;
4. make parameters and structured inputs discoverable through ordinary tool
   help or a machine-readable schema;
5. verify both the reusable mechanism and the originating workflow.

Do not promote code merely because it was used more than once. Preserve narrow,
composable public APIs and keep implementation details private.

## Safety

- Prefer preview, explicit output paths, verification, and native undo units.
- Never silently overwrite a source artifact.
- Keep personal source documents and generated output out of public examples.
- Treat application state and on-disk packages as separate execution targets.
