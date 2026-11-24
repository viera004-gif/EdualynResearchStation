# MB04 Phase 1 evidence contract

- **Test identity** is a monotonically increasing pulse ID within a standalone session. ID 0 is a retained pre-session observation.
- **Route state** is the service mode, launched channel, and measurement tap at launch. The resulting snapshot belongs to that test even if controls move during transit.
- **Physical arrival** is an ordered witness record with a pulse ID, witness ID, channel, and arrival kind. A witness absent from the result did not actuate on that test.
- **Sampled report** carries its own pulse ID, sampled channel, and detected state. Sample age and disagreement with current physical transfer are separate facts.
- **Retained receipt** holds a completed result and compares its launch setup and revision with the current setup. A setup change never rewrites the result. A receipt stays previous even if controls return to the same values before a retest.

Both Phase 1 router modes deliver the backbone pulse through A, B in, B out, and C. Isolation disconnects the auxiliary branch, leaving this backbone intact. B's original tap holds pulse 0, which reported no detection. The alternate live pickup gives B a current sample without changing the transfer path.

The truth table specifies all four playable combinations. The model probe also constructs missing and cross-channel arrivals to test the gate without introducing another playable family. Normal-service confirmation requires the live measurement pickup, all four physical witnesses in the intended channel, current matching reports from A/B/C, no unexpected arrivals, and a receipt from the current configuration revision. An isolated run can produce coherent diagnostic evidence without confirming service.

Witness contacts latch at test completion and stay raised with their receipt. During a new pulse, the prior receipt stays available while the router indicates transit. An alteration marks the previous evidence without clearing it. A new completed test replaces the displayed receipt.

## Raw trace

Each test event carries a shared attempt UUID, prior completed test UUID, pulse ID, and launch snapshot. The result adds physical witness states, reports with explicit sample freshness, and the conflict node IDs. Progress events mark discrete arrivals. They carry the same attempt UUID and never represent test outcomes. The route selector's before/after mode records its isolation change as part of the one physical action. Hardware changes have their own event UUID and link to the latest retained test and any in-flight attempt. `standalone_success` records confirmation without saving chapter progression.

## Standalone verification

Open `res://scenes/main/competing_signals_phase1.tscn` as the current scene. The project default remains the live Module Bay game. In the graybox, WASD and mouse navigate, F operates the targeted object, and Escape frees the cursor.

The deterministic check is `--headless --script res://verification/mb04_phase1/model_probe.gd`. The rendered check is `--script res://verification/mb04_phase1/sector_probe.gd` with the project’s Mobile renderer. It sends tests using in-engine movement and input and writes the local trace, five performance samples, and captures under `.cache`. The trace is local and does not open an API or progression session.

The regression probe starts the normal game and reuses the existing MB01 and MB02 walkthroughs before exercising the MB03 independent balance. Run `--script res://verification/mb04_phase1/regression_probe.gd` with user arguments `--verify --verify-mb02-refinement --locale=en --coolant-config=C --progress-file=res://.cache/mb04_regression_fresh.json --api-base=http://127.0.0.1:1/api/v2/research-station`. Use a fresh progress path for each run.
