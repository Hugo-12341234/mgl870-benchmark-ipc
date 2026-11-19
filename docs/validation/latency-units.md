# Validation de l’unité des latences k6 dans Prometheus

Date de validation : 18 novembre 2026.

## Objectif

Vérifier l’unité utilisée par la sortie Prometheus Remote Write de k6 pour une
`Trend` marquée comme une durée. Cette validation explique pourquoi les
captures historiques affichaient des valeurs cohérentes avec des secondes tout
en portant à tort le suffixe `ms` dans Grafana.

## Protocole contrôlé

Le script [`tests/latency_unit_validation.js`](../../tests/latency_unit_validation.js)
ajoute exactement la même valeur numérique, `1000`, à deux métriques :

- `latency_unit_validation_duration`, une `Trend` temporelle (`isTime=true`);
- `latency_unit_validation_plain`, une `Trend` sans unité (`isTime=false`).

Le résumé k6 et les gauges p99 brutes reçues par Prometheus sont ensuite
comparés. Le test est automatisé par
[`tests/validate_latency_units.ps1`](../../tests/validate_latency_units.ps1).

## Résultats

| Source | Trend temporelle | Trend sans unité |
| --- | ---: | ---: |
| Résumé k6 p95 | `1000` ms | `1000` |
| Gauge Prometheus p99 | `1` | `1000` |

Sortie Prometheus observée :

```text
k6_latency_unit_validation_duration_p99{probe="exact_1000", scenario="default"} => 1
k6_latency_unit_validation_plain_p99{probe="exact_1000", scenario="default"} => 1000
```

La sortie Prometheus convertit donc une durée k6 de `1000 ms` en `1 s`, tandis
que la valeur sans unité demeure `1000`. Les dashboards historiques déclaraient
incorrectement ces valeurs en millisecondes. Les unités des six panneaux p50,
p95 et p99 ont été corrigées de `ms` vers `s`; les données et le classement des
protocoles ne sont pas modifiés.

## Environnement de validation

- Docker Engine `28.0.4`;
- k6 `v2.4.0`, image `grafana/k6@sha256:3d8e5c7f1d53ec59408c2ffbd9943602a0985ffcbd4a2430ec00f3ffca89796e`;
- Prometheus `prom/prometheus@sha256:e04987641b57704f408e31f6373ba4138ecf27cb4a165d24aabb6c38fddd0f06`.

## Reproduction

À partir de la racine du dépôt :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate_latency_units.ps1
```

Le résumé k6 est écrit dans
`results/validation/latency_unit_validation_summary.json`. Le script arrête ensuite
Prometheus sans supprimer le volume de validation.
