"""Generate three Beamer frames from the actual MI + lmtp study summary.

Writes only to this private working directory. Publishing is a separate action.
The default final mode refuses partial results; --draft permits layout review.
"""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
STUDY = HERE.parents[1] / "results" / "imputation"
parser = argparse.ArgumentParser()
parser.add_argument("--draft", action="store_true")
parser.add_argument("--talk-source", type=Path, required=True)
args = parser.parse_args()

summary_path = STUDY / "summary.csv"
summary = list(csv.DictReader(summary_path.open()))
methods = ["mi_tmle", "mi_sdr", "bridge_tmle", "bridge_sdr"]
scenarios = ["mar_only", "shadow_only", "both"]
lookup = {(r["scenario"], int(r["n"]), r["method"]): r for r in summary}
assert len(lookup) == 24
assert all(int(r["failures"]) == 0 for r in summary), "Investigate failed estimates before presenting results"
counts = {int(r["completed"]) for r in summary}
if not args.draft:
    assert (STUDY / "COMPLETED.txt").exists(), "Study validation/reporting has not finished"
    assert len(list((STUDY / "jobs").glob("*.rds"))) == 1200
    assert counts == {200}, "Final table must contain 200 replicates in every cell"
    assert (STUDY / "VALIDATION.md").exists()

replicates = list(csv.DictReader((STUDY / "replicates.csv").open()))
table_rows = []
for scenario in scenarios:
    for n in [1000, 4000]:
        cells = []
        for method in methods:
            r = lookup[scenario, n, method]
            values = [float(v["estimate"]) for v in replicates
                      if v["scenario"] == scenario and int(v["n"]) == n and v["method"] == method]
            assert len(values) == int(r["successful"])
            mse = sum((v - .75) ** 2 for v in values) / len(values)
            assert abs(mse - float(r["rmse"]) ** 2) < 1e-12
            mean = f'{float(r["mean_estimate"]):.3f}'
            coverage = f'{100 * float(r["coverage"]):.1f}'
            cells.append(r"\shortstack{$" + mean + r"$ ($" + coverage + r"$)\\[-1pt]$" + f"{1000*mse:.2f}" + "$}")
        label = {"mar_only": "MAR only", "shadow_only": "Shadow only", "both": "Both hold"}[scenario]
        table_rows.append(f"{label if n == 1000 else ''} & {n:,} & " + " & ".join(cells) + r" \\")
        if n == 4000 and scenario != "both":
            table_rows.append(r"\addlinespace[5pt]")

overview = r"""% BEGIN CMBridge MI comparison: main slides
% One treatment decision, identical full-data distribution in all scenarios.
\begin{frame}{Simulation: multiple imputation and bridge estimation}
One treatment decision with a partially observed binary outcome.
The target is $\theta=\E\{Y_2(1)\}=0.75$.

\begin{block}{Vary the missingness assumptions}
\centering
\begin{tabular}{@{}lcc@{}}
\toprule
 & MAR & Shadow restriction\\
 & $R_2\indep Y_2\mid W,A_1$ & $R_2\indep A_1\mid W,Y_2$\\
\midrule
MAR only & Holds & Fails\\
Shadow only & Fails & Holds\\
Both hold & Holds & Holds\\
\bottomrule
\end{tabular}
\end{block}

\begin{block}{Four estimators, one target}
\begin{itemize}
\item \textbf{MI + TMLE and MI + SDR:} 50 logistic imputations.
Fit standard \texttt{lmtp} estimators to each completion and pool each method
with Rubin's rules.
\item \textbf{Bridge TMLE and bridge SDR:} estimate from the observed data
under the shadow restriction.
\item Saturated binary models avoid extra functional-form restrictions.
Use three shared outer folds.
\end{itemize}
\end{block}
\smallskip\textcolor{nyuviolet}{200 replications per setting, $n=1{,}000$ and
$4{,}000$, with 35\% of outcomes missing on average.}
\end{frame}
"""
count_label = "200 replications per scenario and sample size" if not args.draft else (
    f"Preliminary: {min(counts)}--{max(counts)} replications per scenario and sample size")
results = r"""
\begin{frame}{Simulation results}
True mean: $0.75$. """ + count_label + r""".

\medskip
\begin{center}
\setlength{\tabcolsep}{4pt}
\renewcommand{\arraystretch}{1.05}
\begin{tabular}{@{}lrcccc@{}}
\toprule
Scenario & $n$ & MI + TMLE & MI + SDR & Bridge TMLE & Bridge SDR\\
\midrule
""" + "\n".join(table_rows) + r"""
\bottomrule
\end{tabular}
\end{center}
\smallskip
\textbf{Cell format:} mean (95\% interval coverage, \%) above
$1{,}000\times\mathrm{MSE}$.

\takeaway{The results favor the method whose identifying assumption holds.
When both hold, MI has lower MSE in this simulation.}
\end{frame}
% END CMBridge MI comparison: main slides
"""
appendix = r"""% BEGIN CMBridge MI comparison: appendix
\appendix
\begingroup
\setbeamertemplate{footline}{\hfill\usebeamerfont{page number in head/foot}\insertpagenumber\kern1em\vskip2pt}
\begin{frame}{Appendix: simulation data-generating process}
\begin{block}{Full-data law}
Generate each variable with an independent Bernoulli draw conditional on its parents:
\[
\begin{aligned}
W &\sim \operatorname{Bernoulli}(0.5),\\
A_1\mid W &\sim \operatorname{Bernoulli}(0.4+0.2W),\\
Y_2\mid W,A_1 &\sim \operatorname{Bernoulli}(0.2+0.1W+0.5A_1).
\end{aligned}
\]
\end{block}

\begin{block}{Measurement law}
$R_2\mid W,A_1,Y_2\sim\operatorname{Bernoulli}\{\pi(W,A_1,Y_2)\}$, with
\begin{center}
\begin{tabular}{@{}ll@{}}
\toprule
Scenario & $\pi(W,A_1,Y_2)$\\ \midrule
MAR only & $0.5+0.1W+0.2A_1$\\
Shadow only & $0.8+0.1W-0.4Y_2$\\
Both hold & $0.6+0.1W$\\ \bottomrule
\end{tabular}
\end{center}
$W$ and $A_1$ are fully observed. Record $Y_2$ only when $R_2=1$.
In each scenario, $\P(R_2=0)=0.35$.
\end{block}
\takeaway{Assigning $A_1=1$ gives $\E\{Y_2(1)\}=0.7+0.1\E(W)=0.75$.}
\end{frame}
\endgroup
% END CMBridge MI comparison: appendix
"""

talk = args.talk_source.read_text()
assert r"\begin{document}" in talk and talk.count(r"\end{document}") == 1
for section in ["main slides", "appendix"]:
    talk = re.sub(r"% BEGIN CMBridge MI comparison: " + section +
                  r".*?% END CMBridge MI comparison: " + section + r"\n?", "", talk, flags=re.S)
original_frames = talk.count(r"\begin{frame}")
anchor = r"\begin{frame}{What the framework contributes}"
assert talk.count(anchor) == 1, "The talk structure changed; inspect the insertion point"
first_added_slide = talk[:talk.index(anchor)].count(r"\begin{frame}") + 1
main_slides = overview + results
integrated = talk.replace(anchor, main_slides + "\n" + anchor)
integrated = integrated.replace(r"\end{document}", appendix + "\n" + r"\end{document}")
assert integrated.count(r"\begin{frame}") == original_frames + 3

preamble = talk.split(r"\begin{document}")[0]
preview = preamble + "\\begin{document}\n" + main_slides + appendix + "\n\\end{document}\n"
assert preview.count(r"\begin{frame}") == 3
(HERE / "simulation-slides.tex").write_text(preview)
(HERE / "slides-with-simulation.tex").write_text(integrated)
(HERE / "simulation-frames.tex").write_text(main_slides + appendix)
provenance = dict(final=not args.draft, original_source=str(args.talk_source),
    original_sha256=hashlib.sha256(args.talk_source.read_bytes()).hexdigest(),
    summary_sha256=hashlib.sha256(summary_path.read_bytes()).hexdigest(),
    source_fingerprint=(STUDY / "fingerprint.txt").read_text().strip(),
    replications=sorted(counts), original_frames=original_frames,
    integrated_frames=original_frames+3, added_frames=3,
    added_slides=[first_added_slide, first_added_slide+1, original_frames+3],
    packages={"cmbridge":"0.3.0.9020", "lmtp":"1.6.0.9021", "mice":"3.19.0"})
(HERE / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
print(json.dumps(provenance, indent=2))
