# Four-scenario Harvard update

Delivered October 10, 2026 at 20:07 EDT to the existing Harvard 2026 talk.
Updated pages 27, 28, and 30 of the 31-page deck, retaining the current user
edits and longitudinal simulation frames. The other 28 pages render identically
to the current source. The old PDF was stale on page 14; its newer source edit
was retained in the rebuilt PDF.

Inputs: validated results/imputation, 1,600 datasets, 6,400 returned estimates,
160,000 standard completed-data lmtp fits, 200 replications per cell. All means,
coverage proportions, and MSE values were independently reconstructed from
the replicate table. Original 1,200 checkpoint hashes and result rows remain
unchanged; all 1,600 final checkpoint hashes were independently verified.

The neither scenario uses response probability
0.675 + 0.1 W + 0.15 A1 - 0.3 Y2. Its two population functionals equal
0.663743991454513, giving equal population bias -0.086256008545487 against
the causal target 0.75. Empirical biases need not agree exactly.

build_slides.py updates only the existing marked MI blocks, guards the current
source structure, and refuses incomplete results. It preserves source content
outside those blocks exactly. publish_slides.py verifies source/PDF concurrency
hashes, retains backups, and atomically replaces each final file after inspection.
All talk copies, rendered images, backups, and delivery receipts remain private
and are excluded from Git. Both native and MacTeX compilation succeeded; the
three changed pages were visually inspected with no clipping or overflow.

The frozen simulation fitting sources and packages were not changed. After
aggregation, report prose was corrected to remove an obsolete deleted-folder
reference, and the canonical validation report's relative link was fixed.
