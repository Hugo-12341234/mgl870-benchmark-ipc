# Résultats expérimentaux

## Campagne officielle

[`rerun_20261119-104900/`](rerun_20261119-104900/) est la campagne utilisée dans le rapport final. Elle contient cinq runs unitaires et cinq runs batch. Chaque run conserve :

- `k6_summary.json` : compteurs et percentiles par protocole en millisecondes;
- `prometheus.json` : séries temporelles, avec les latences en secondes;
- `manifest.json` : identité du run, période UTC, commit, Docker et hôte.

Le dossier [`summary/`](rerun_20261119-104900/summary/) contient les CSV consolidés, le choix des runs représentatifs et un rapport de validation automatisé. La campagne passe 75 contrôles sur 75.

## Validation des unités

[`validation/`](validation/) contient le résultat du test synthétique ayant confirmé la conversion des tendances temporelles k6 entre les résumés et Prometheus. Le protocole est documenté dans [`docs/validation/latency-units.md`](../docs/validation/latency-units.md).

## Archive

[`archive/legacy_pre_validation/`](archive/legacy_pre_validation/) conserve les dix résumés de la campagne initiale. Cette campagne reproduit les mêmes classements et des débits globaux proches, mais ses captures Grafana utilisaient une métadonnée d’unité incorrecte. Elle n’est donc pas la source officielle des valeurs absolues du rapport.
