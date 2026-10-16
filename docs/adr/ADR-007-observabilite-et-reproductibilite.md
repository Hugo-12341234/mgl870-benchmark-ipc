# ADR-007 : Centraliser l’observabilité et conserver les artefacts

- **Statut :** Acceptée
- **Date :** 2026-10-16
- **Décideurs :** Projet MGL870

## Contexte

Une comparaison de performance est difficile à défendre si elle ne conserve que des valeurs finales. Il faut relier la latence et le débit aux ressources, vérifier les erreurs et permettre à une autre personne de reproduire le protocole.

## Décision

Utiliser k6 pour les métriques applicatives, Prometheus pour leur collecte, cAdvisor et `docker-metrics` pour les métriques de conteneurs, et Grafana pour l’exploration temporelle. Conserver les scripts, la configuration Docker, le contrat `.proto`, les JSON de chaque run, les captures Grafana, les dashboards et les sources PlantUML dans le dépôt.

## Options considérées

1. Conserver uniquement les résumés k6.
2. Utiliser uniquement des captures manuelles.
3. Combiner les données sources, la télémétrie temporelle et les artefacts versionnés.

## Justification

La troisième option permet de vérifier les checks, la saturation CPU, les tendances temporelles et la stabilité inter-runs. Elle distingue les données quantitatives des illustrations et évite de choisir une capture sans conserver les autres runs.

## Conséquences

Le dépôt contient davantage d’artefacts et exige une organisation claire des répertoires. Les captures Grafana restent des représentations visuelles; les JSON et les séries Prometheus demeurent les sources de vérification quantitative.

## Preuves disponibles

Les répertoires `results/`, `docs/screenshots/`, `grafana/`, `tests/`, `proto/`, `docs/figures/` et `docs/adr/` rendent la chaîne d’expérimentation auditable.
