"""Verify saved simulation summaries and rebuild the manuscript tables/figure.

This script reads completed results only. It never fits a model or changes a
simulation checkpoint. Run with Python 3 and Rscript from a checkout of this repository.
"""
from pathlib import Path
import csv
import hashlib
import json
import math
from collections import defaultdict
from statistics import mean, stdev
import subprocess

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parent
RESULTS = ROOT / "results"
LONG = RESULTS / "longitudinal/full500-github-20261013/early-summary"
MI = RESULTS / "imputation"
TABLES = HERE / "simulation_tables"
TABLES.mkdir(exist_ok=True)
(HERE / "figures").mkdir(exist_ok=True)


def read(path):
    with path.open(newline="") as stream:
        return list(csv.DictReader(stream))


def close(actual, expected, key):
    if not math.isclose(actual, float(expected), rel_tol=1e-9, abs_tol=1e-11):
        raise AssertionError((key, actual, expected))


long_rows = read(LONG / "replicates.csv")
long_summary = read(LONG / "summary.csv")
long_failures = read(LONG / "errors.csv")
mi_rows = read(MI / "replicates.csv")
mi_summary = read(MI / "summary.csv")
long_groups = defaultdict(list)
mi_groups = defaultdict(list)
for row in long_rows:
    long_groups[(row["mechanism"], int(row["n"]), int(row["horizon"]), row["estimator"])].append(row)
for row in mi_rows:
    mi_groups[(row["scenario"], int(row["n"]), row["method"])].append(row)
assert len(long_rows) == 15832 and len(mi_rows) == 6400
assert len(long_summary) == len(mi_summary) == 32
successful_datasets = {(r["mechanism"], r["n"], r["replicate"]) for r in long_rows}
failed_datasets = {(r["mechanism"], r["n"], r["replicate"]) for r in long_failures}
assert len(successful_datasets) == 3958 and len(failed_datasets) == 42
assert not successful_datasets.intersection(failed_datasets)
assert len({(r["scenario"], r["n"], r["replicate"]) for r in mi_rows}) == 1600

for summary in long_summary:
    key = (summary["mechanism"], int(summary["n"]), int(summary["horizon"]), summary["estimator"])
    rows = long_groups[key]
    assert len(rows) == int(summary["successful"])
    assert len({r["replicate"] for r in rows}) == len(rows)
    assert len(rows) + int(summary["failed"]) == 500
    errors = [float(r["estimate"]) - float(r["truth"]) for r in rows]
    values = [float(r["estimate"]) for r in rows]
    cover = [float(r["lower"]) <= float(r["truth"]) <= float(r["upper"]) for r in rows]
    close(mean(values), summary["mean_estimate"], (key, "mean"))
    close(mean(errors), summary["bias"], (key, "bias"))
    close(math.sqrt(key[1]) * mean(errors), summary["root_n_bias"], (key, "scaled bias"))
    close(key[1] * mean(e * e for e in errors), summary["n_mse"], (key, "scaled MSE"))
    close(stdev(values), summary["empirical_sd"], (key, "SD"))
    close(mean(cover), summary["coverage"], (key, "coverage"))
    close(mean(float(r["se"]) for r in rows), summary["mean_se"], (key, "SE"))
    close(mean(float(r["se"]) ** 2 for r in rows) / stdev(values) ** 2,
          summary["variance_ratio"], (key, "variance ratio"))
    close(mean(r["joint_curve_covered"] == "TRUE" for r in rows),
          summary["joint_curve_coverage"], (key, "joint coverage"))

for summary in mi_summary:
    key = (summary["scenario"], int(summary["n"]), summary["method"])
    rows = mi_groups[key]
    assert len(rows) == 200 and len({r["replicate"] for r in rows}) == 200
    assert not any(r["error"] for r in rows)
    values = [float(r["estimate"]) for r in rows]
    assert all(float(r["truth"]) == 0.75 for r in rows)
    close(mean(values), summary["mean_estimate"], (key, "mean"))
    close(mean(values) - 0.75, summary["bias"], (key, "bias"))
    close(mean((x - 0.75) ** 2 for x in values), summary["mse"], (key, "MSE"))
    close(mean(float(r["lower"]) <= 0.75 <= float(r["upper"]) for r in rows),
          summary["coverage"], (key, "coverage"))

long_map = {(r["mechanism"], int(r["n"]), int(r["horizon"]), r["estimator"]): r for r in long_summary}
mi_map = {(r["scenario"], int(r["n"]), r["method"]): r for r in mi_summary}
mechanisms = [("binary_longitudinal", "Binary treatment"), ("discrete_dose", "Numerical dose")]
sizes = [500, 1000, 4000, 10000]
f = lambda row, name: float(row[name])
pct = lambda x: f"{100 * x:.1f}"
number = lambda x: f"{x:,}"

lines = [r"% Generated from verified saved replications; do not edit numerical entries.",
         r"\begin{table}[!htbp]", r"\centering\small", r"\setlength{\tabcolsep}{4pt}",
         r"\caption{Longitudinal simulation results from 500 datasets per setting. Bias is multiplied by $\sqrt n$ and MSE by $n$. Coverage is the percentage of returned pointwise 95\% intervals containing the truth; $N$ is the number of returned fits for each estimator. Failed datasets are retained in the counts and are not replaced.}",
         r"\label{tab:sim-longitudinal}", r"\begin{tabular}{lrr*{6}{r}}", r"\toprule",
         r"& & & \multicolumn{2}{c}{$\sqrt n\times$ Bias} & \multicolumn{2}{c}{$n\times$ MSE} & \multicolumn{2}{c}{Coverage (\%)}\\",
         r"Treatment & $n$ & $N$ & SDR & TMLE & SDR & TMLE & SDR & TMLE\\", r"\midrule"]
for horizon in [1, 2]:
    lines.append(r"\multicolumn{9}{l}{\textit{Outcome at time " + str(horizon + 1) + r"}}\\")
    for mechanism, label in mechanisms:
        for index, n in enumerate(sizes):
            sdr, tmle = [long_map[mechanism, n, horizon, method] for method in ["sdr", "tmle"]]
            assert sdr["successful"] == tmle["successful"]
            cells = [label if index == 0 else "", number(n), sdr["successful"],
                     f"{f(sdr, 'root_n_bias'):.3f}", f"{f(tmle, 'root_n_bias'):.3f}",
                     f"{f(sdr, 'n_mse'):.3f}", f"{f(tmle, 'n_mse'):.3f}",
                     pct(f(sdr, "coverage")), pct(f(tmle, "coverage"))]
            lines.append(" & ".join(cells) + r"\\")
        lines.append(r"\addlinespace")
    if horizon == 1:
        lines.append(r"\midrule")
lines += [r"\bottomrule", r"\end{tabular}", r"\end{table}"]
(TABLES / "longitudinal.tex").write_text("\n".join(lines) + "\n")

scenarios = [("mar_only", "MAR only"), ("shadow_only", "Shadow restriction only"),
             ("both", "Both restrictions"), ("neither", "Neither restriction")]
methods = [("mi_tmle", "MI + TMLE"), ("mi_sdr", "MI + SDR"),
           ("bridge_tmle", "Bridge TMLE"), ("bridge_sdr", "Bridge SDR")]
lines = [r"% Generated from verified saved replications; do not edit numerical entries.",
         r"\begin{table}[!htbp]", r"\centering\small", r"\setlength{\tabcolsep}{7pt}",
         r"\caption{Comparison with multiple imputation under MAR. The causal target is $\E\{Y_2(1)\}=0.75$ in every scenario. Each row uses 200 datasets, with no failed final estimates. Coverage is for nominal 95\% intervals. MSE is multiplied by $10^3$.}",
         r"\label{tab:sim-mar}", r"\begin{tabular}{rlrrrr}", r"\toprule",
         r"$n$ & Method & Mean & Bias & $10^3\times$ MSE & Coverage (\%)\\", r"\midrule"]
for scenario, label in scenarios:
    lines.append(r"\multicolumn{6}{l}{\textit{" + label + r"}}\\")
    for n in [1000, 4000]:
        for index, (method, method_label) in enumerate(methods):
            row = mi_map[scenario, n, method]
            cells = [number(n) if index == 0 else "", method_label,
                     f"{f(row, 'mean_estimate'):.4f}", f"{f(row, 'bias'):.4f}",
                     f"{1000 * f(row, 'mse'):.3f}", pct(f(row, "coverage"))]
            lines.append(" & ".join(cells) + r"\\")
        lines.append(r"\addlinespace[2pt]")
    if scenario != "neither":
        lines.append(r"\midrule")
lines += [r"\bottomrule", r"\end{tabular}", r"\end{table}"]
(TABLES / "mar.tex").write_text("\n".join(lines) + "\n")

lines = [r"\begin{table}[htbp]", r"\centering\small", r"\setlength{\tabcolsep}{4pt}",
         r"\caption{Variance estimation and coverage in the longitudinal study. SD and mean SE refer to the final-outcome estimate and use returned fits. VR is the mean squared SE divided by the empirical variance of estimates. The final two columns count failed fits as noncovering: pointwise coverage at time 3 and simultaneous coverage of the two-outcome curve. Each setting contains 500 generated datasets.}",
         r"\label{tab:sim-variance}", r"\begin{tabular}{lrlrrrrr}", r"\toprule",
         r"Treatment & $n$ & Method & SD & Mean SE & VR & Pointwise (\%) & Curve (\%)\\", r"\midrule"]
for mechanism, label in mechanisms:
    for index, n in enumerate(sizes):
        for method_index, method in enumerate(["sdr", "tmle"]):
            row = long_map[mechanism, n, 2, method]
            fraction = int(row["successful"]) / 500
            cells = [label if index == method_index == 0 else "", number(n) if method_index == 0 else "", method.upper(),
                     f"{f(row, 'empirical_sd'):.4f}", f"{f(row, 'mean_se'):.4f}", f"{f(row, 'variance_ratio'):.3f}",
                     pct(f(row, "coverage") * fraction), pct(f(row, "joint_curve_coverage") * fraction)]
            lines.append(" & ".join(cells) + r"\\")
        lines.append(r"\addlinespace[2pt]")
    lines.append(r"\midrule" if mechanism == "binary_longitudinal" else r"\bottomrule")
lines += [r"\end{tabular}", r"\end{table}"]
(TABLES / "variance.tex").write_text("\n".join(lines) + "\n")

subprocess.run(["Rscript", str(HERE / "scripts/plot_simulations.R"),
                str(LONG / "summary.csv"),
                str(HERE / "figures/simulation-longitudinal")], check=True)

inputs = [LONG / name for name in ["replicates.csv", "summary.csv", "errors.csv"]]
inputs += [MI / name for name in ["replicates.csv", "summary.csv"]]
audit = {"longitudinal_datasets": 4000, "longitudinal_successful_datasets": 3958,
         "longitudinal_failed_datasets": 42, "longitudinal_estimate_rows": len(long_rows),
         "imputation_datasets": 1600, "imputation_estimate_rows": len(mi_rows),
         "summary_cells_verified": 64, "all_checks_passed": True,
         "inputs": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in inputs}}
(TABLES / "verification.json").write_text(json.dumps(audit, indent=2) + "\n")
print(json.dumps({key: value for key, value in audit.items() if key != "inputs"}, indent=2))
