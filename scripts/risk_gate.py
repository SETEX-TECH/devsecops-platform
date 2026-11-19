#!/usr/bin/env python3
"""Porte de décision de déploiement basée sur un score de risque (0-100).

Politique :
- CRITICAL (avec ou sans correctif) : blocage.
- HIGH : blocage seulement si plus de MAX_HIGH ont un correctif disponible.
- Les vulnérabilités sans correctif restent dans le score avec un poids réduit
  (UNFIXED_FACTOR) et dans le rapport, mais ne bloquent pas par leur nombre.
"""
import json
import os
import sys

WEIGHTS = {"CRITICAL": 25, "HIGH": 8, "MEDIUM": 2, "LOW": 0.5, "UNKNOWN": 0.5}
ALLOW_BELOW = float(os.getenv("RISK_ALLOW_BELOW", 30))
BLOCK_ABOVE = float(os.getenv("RISK_BLOCK_ABOVE", 70))
MAX_HIGH = int(os.getenv("MAX_HIGH", 5))
UNFIXED_FACTOR = float(os.getenv("UNFIXED_FACTOR", 0.1))
EXPOSED = os.getenv("SERVICE_EXPOSED", "true").lower() == "true"


def load_vulns(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    for result in data.get("Results", []) or []:
        for v in result.get("Vulnerabilities", []) or []:
            yield v


def compute_score(vulns):
    counts = {k: 0 for k in WEIGHTS}
    fixable = {k: 0 for k in WEIGHTS}
    score = 0.0
    for v in vulns:
        sev = v.get("Severity", "UNKNOWN")
        counts[sev] = counts.get(sev, 0) + 1
        w = WEIGHTS.get(sev, 0.5)
        if v.get("FixedVersion"):
            fixable[sev] = fixable.get(sev, 0) + 1
        else:
            w *= UNFIXED_FACTOR
        score += w
    if EXPOSED:
        score *= 1.2
    return min(round(score, 1), 100.0), counts, fixable


def main():
    report = sys.argv[1] if len(sys.argv) > 1 else "trivy-image.json"
    score, counts, fixable = compute_score(load_vulns(report))

    if counts["CRITICAL"] > 0 or fixable["HIGH"] > MAX_HIGH or score > BLOCK_ABOVE:
        decision = "block"
    elif score >= ALLOW_BELOW:
        decision = "review"
    else:
        decision = "allow"

    summary = (
        f"### Porte de risque\n\n"
        f"- Score : **{score}/100**\n"
        f"- Décision : **{decision}**\n"
        f"- Critiques : {counts['CRITICAL']} | Hautes : {counts['HIGH']} "
        f"(dont {fixable['HIGH']} avec correctif) | "
        f"Moyennes : {counts['MEDIUM']} | Basses : {counts['LOW']}\n"
    )
    print(summary)
    if os.getenv("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(summary)
    if os.getenv("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as f:
            f.write(f"score={score}\ndecision={decision}\n")

    sys.exit(1 if decision == "block" else 0)


if __name__ == "__main__":
    main()
