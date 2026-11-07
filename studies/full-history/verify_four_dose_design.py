"""Exact population checks for the two four-dose longitudinal designs."""

from fractions import Fraction as F
from math import comb
from operator import itemgetter


# Nine-point closed Newton–Cotes on [0, 1] is exact through degree nine.
GRID = tuple(
    (F(i, 8), F(w, 28350))
    for i, w in enumerate((989, 5888, -928, 10496, -4540, 10496, -928, 5888, 989))
)
UNIFORM_DOSE = (F(1, 4),) * 4
ZERO_DOSE = (F(1), F(0), F(0), F(0))


def treatment(state, increase=False):
    y, x = state
    z = (y + x) / 2
    g = ((14 - 8 * z) / 60, (22 - 4 * z) / 60, (19 + 2 * z) / 60, (5 + 10 * z) / 60)
    dose = (F(0), g[0], g[1], g[2] + g[3]) if increase else g
    return dose, F(1, 4) + z / 2


def density(d, y, v):
    dose_component = 4 * comb(3, d) * v**d * (1 - v)**(3 - d)
    history_component = 3 * ((1 - y) * (1 - v)**2 + y * v**2)
    return (dose_component + history_component) / 2


def bernoulli(prob):
    return ((0, 1 - prob), (1, prob))


def health(v, x):
    return (x + 7 * v) / 8, x


def visit(state):
    y, x = state
    return F(1, 4) + y / 4 + F(x, 8)


def mean_given_assignment(state, dose, prob_b):
    y, _ = state
    _, e = treatment(state)
    prob_x = (e + prob_b) / 2
    dose_mean = sum(p * (a + 1) / 5 for a, p in enumerate(dose))
    history_mean = F(1, 4) + y / 2
    return prob_x / 8 + 7 * (dose_mean + history_mean) / 16


def targets(design, policy):
    """Integrate over baseline, first health transition, and intermediate attendance."""
    theta2 = theta3 = prob_r2 = F(0)
    for y1, wy in GRID:
        for x1, wx in bernoulli(F(1, 4) + y1 / 2):
            state1 = (y1, x1)
            q1, e1 = treatment(state1, policy)
            theta2 += wy * wx * mean_given_assignment(state1, q1, e1)
            for x2, px in bernoulli(e1):
                for v2, wv in GRID:
                    state2 = health(v2, x2)
                    density_v2 = sum(q * density(d, y1, v2) for d, q in enumerate(q1))
                    mass = wy * wx * px * wv * density_v2
                    r2 = visit(state2)
                    prob_r2 += mass * r2
                    q_visit, e_visit = treatment(state2, policy)
                    if design == "observed":
                        q_miss, e_miss = treatment(state1)
                    else:
                        q_miss = UNIFORM_DOSE if policy else ZERO_DOSE
                        e_miss = F(0)
                    visit_mean = mean_given_assignment(state2, q_visit, e_visit)
                    missed_mean = mean_given_assignment(state2, q_miss, e_miss)
                    theta3 += mass * (r2 * visit_mean + (1 - r2) * missed_mean)
    return theta2, theta3, prob_r2


def action_density(states, d, b, x_next, v):
    """Marginalize the true current state conditional on the history used for assignment."""
    total = F(0)
    for state, weight in states:
        _, e = treatment(state)
        prob_x = (e + b) / 2
        px = prob_x if x_next else 1 - prob_x
        total += weight * px * density(d, state[0], v)
    return total


def hidden_states(baseline, d1, b1):
    """Exact quadrature for C2 conditional on H2 when visit 2 was missed."""
    _, e1 = treatment(baseline)
    masses = []
    for x2, prob_x2 in bernoulli((e1 + b1) / 2):
        for v, wv in GRID:
            state = health(v, x2)
            mass = prob_x2 * wv * density(d1, baseline[0], v) * (1 - visit(state))
            masses.append((state, mass))
    total = sum(mass for _, mass in masses)
    return [(state, mass / total) for state, mass in masses]


def solve(matrix, rhs):
    """Solve an eight-by-eight system exactly and fail if an action row is redundant."""
    rows = [list(row) + [value] for row, value in zip(matrix, rhs)]
    for col in range(len(rows)):
        pivot = next(i for i in range(col, len(rows)) if rows[i][col])
        rows[col], rows[pivot] = rows[pivot], rows[col]
        rows[col] = [value / rows[col][col] for value in rows[col]]
        for i, row in enumerate(rows):
            if i != col:
                rows[i] = [a - row[col] * b for a, b in zip(row, rows[col])]
    return [row[-1] for row in rows]


def check_range(states, history, branch, loading):
    """Solve at four points per binary state and check an overdetermined grid."""
    natural, e = treatment(history)
    if branch == "uniform":
        q, prob_b = UNIFORM_DOSE, F(0)
    else:
        q, prob_b = treatment(history, increase=(branch == "increase"))
    actions = [(d, b) for d in range(4) for b in (0, 1)]

    def system_row(v, x_next):
        rows = [action_density(states, d, b, x_next, v) for d, b in actions]
        natural_joint = [
            row * natural[d] * (e if b else 1 - e) for row, (d, b) in zip(rows, actions)
        ]
        policy_density = sum(
            row * q[d] * (prob_b if b else 1 - prob_b) for row, (d, b) in zip(rows, actions)
        )
        return natural_joint, policy_density * loading(health(v, x_next))

    fit = [system_row(F(j, 3), x) for x in (0, 1) for j in range(4)]
    representer = solve([row for row, _ in fit], [rhs for _, rhs in fit])
    for x in (0, 1):
        for v, _ in GRID:
            row, target = system_row(v, x)
            assert sum(a * l for a, l in zip(row, representer)) == target


def continuation_mean(state):
    y, x = state
    return (22 + 15 * y + x) / 64


def verify_identities():
    for degree in range(10):
        assert sum(w * v**degree for v, w in GRID) == F(1, degree + 1)
    for y, _ in GRID:
        for d in range(4):
            null = sum(
                w * density(d, y, v) * (70 * v**4 - 140 * v**3 + 90 * v**2 - 20 * v + 1)
                for v, w in GRID
            )
            assert null == 0
        for x in (0, 1):
            state = (y, x)
            assert mean_given_assignment(state, UNIFORM_DOSE, F(0)) == continuation_mean(state)
            for increase in (False, True):
                q, _ = treatment(state, increase)
                assert q[3] - 3 * q[2] + 3 * q[1] - q[0] == 0

    outcome = itemgetter(0)
    examples = ((F(1, 2), 0), (F(3, 4), 1))
    for state in examples:
        complete = [(state, F(1))]
        check_range(complete, state, "increase", outcome)
        check_range(complete, state, "uniform", outcome)
        check_range(complete, state, "increase", continuation_mean)
        # At a missed visit the dose is drawn using baseline but the next health
        # depends on latent C2. Integrate its full conditional law before testing.
        missing = hidden_states(state, d1=2, b1=0)
        check_range(missing, state, "natural", outcome)


if __name__ == "__main__":
    verify_identities()
    expected = {
        ("observed", True): (F(55, 96), F(390931619, 707788800), F(175, 384)),
        ("observed", False): (F(1, 2), F(2464793, 4915200), F(7, 16)),
        ("full", True): (F(55, 96), F(379546979, 707788800), F(175, 384)),
        ("full", False): (F(1, 2), F(2020193, 4915200), F(7, 16)),
    }
    for (design, policy), reference in expected.items():
        values = targets(design, policy)
        assert values == reference
        print(design, "policy" if policy else "natural",
              "  ".join(f"{v} ({float(v):.9f})" for v in values))
    print("Columns: E[Y2], E[Y3], P(R2=1). Bridge and adjoint checks passed.")
