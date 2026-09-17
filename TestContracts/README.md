# Gesture contracts

The fixtures in `v1/gesture` are deterministic regression cases for Jostle's platform-independent event and gesture reducers. They describe normalized mouse input, geometry, monotonic timestamps, reducer state, and ordered window commands without depending on Accessibility objects or Core Graphics constants.

`JostleCore/Tests/JostleCoreTests/GestureContractTests.swift` discovers and executes every fixture directly from the repository. The JSON shape is documented by `schemas/gesture-case.schema.json`.

When changing gesture behavior:

1. add or update focused reducer unit tests;
2. add a fixture when the scenario spans event routing and multiple gesture steps;
3. keep timestamps deterministic and geometry finite;
4. preserve command ordering, especially position-before-size for top or left resizing;
5. never include real application names, window titles, identifiers, or Accessibility data.
