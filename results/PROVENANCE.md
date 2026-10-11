# Latest studies only

Longitudinal: original GitHub run 37417223244, continuations 37500493830,
37549252226 and 37603169839. All 1,200 unique checkpoints independently verified
on October 10, 2026: 1,177 successful datasets, 23 with failed fits. Duplicate
checkpoints had to match their original bytes. No reruns or selected deletions.

Imputation comparison: the final four-scenario study completed October 10,
2026. It contains 1,600 datasets and 6,400 returned method estimates, with 200
replications in every method/scenario/sample-size cell. Each MI method uses the
same 50 imputations, yielding 160,000 standard lmtp API calls. All 1,600 final
checkpoint hashes, original 1,200 hashes and 24 summary rows, and final means,
coverage and MSE were independently verified. There are no failed final method
estimates or completed-data API calls; the 46 internal candidate failures and
27,385 Landweber iteration-limit stops remain disclosed. Obsolete
MI-standardization results are excluded. Phase audit outputs belong to this
latest study; they are not additional replications in its final tables.

The checkpoint manifests retain SHA256 hashes. Large individual fit objects
remain locally under each result directory's ignored `jobs/` folder; compact
tables, reports and scientific figures are versioned. Historical fingerprints
in saved objects describe the original execution, not the reorganized paths.
The reorganized scripts have a separate source manifest.

Repository organization does not establish correct coverage. The longitudinal
numerical-dose results still have undercoverage at the final outcome time, and
all failures remain reported. Results from different configurations or platforms
are not pooled.
