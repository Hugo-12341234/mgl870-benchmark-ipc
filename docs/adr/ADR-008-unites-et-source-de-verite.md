# ADR-008 : Expliciter les unités et privilégier les données numériques

- **Statut :** Acceptée
- **Date :** 2026-11-18
- **Décideurs :** Projet MGL870

## Contexte

Les résumés k6 expriment les tendances temporelles en millisecondes, tandis que la sortie Prometheus remote write les stocke en secondes. Les premiers dashboards déclaraient incorrectement l’unité `ms`; les courbes et leur classement étaient cohérents, mais leurs valeurs absolues étaient affichées avec une unité erronée. Des captures seules ne suffisent donc pas comme source quantitative.

## Décision

Déclarer les panneaux de latence Grafana en secondes et laisser Grafana adapter automatiquement l’affichage en millisecondes lorsque la valeur est inférieure à une seconde. Conserver, pour chacun des dix runs, les percentiles par protocole dans le résumé k6 en millisecondes et l’export brut Prometheus avec l’unité `seconds`. Utiliser les fichiers numériques comme sources de vérité; utiliser les captures pour illustrer le comportement temporel.

## Options considérées

1. Conserver les anciens dashboards et corriger seulement le texte du rapport.
2. Convertir les requêtes PromQL en millisecondes.
3. Déclarer l’unité native Prometheus, documenter la conversion et archiver les deux sources.

## Justification

La troisième option réduit les conversions implicites et permet de confronter deux représentations indépendantes de la même mesure. Un test synthétique d’une seconde a confirmé qu’une tendance k6 égale à `1000` ms est écrite comme `1` dans Prometheus, tandis qu’une tendance sans unité conserve la valeur `1000`.

## Conséquences

Les nouvelles captures affichent correctement des secondes dans les queues de latence saturées et des millisecondes pour les valeurs plus faibles. Les résultats absolus du rapport doivent être remplacés, mais le classement des protocoles et les formes temporelles de l’ancienne campagne demeurent comparables. L’ancienne campagne est archivée plutôt que présentée comme preuve officielle.

## Preuves disponibles

Le protocole de validation est documenté dans `docs/validation/latency-units.md`; son résultat se trouve dans `results/validation/latency_unit_validation_summary.json`. Les dashboards corrigés, les dix résumés k6, les dix exports Prometheus et les captures officielles permettent l’audit croisé.
