# ADR-004 : Utiliser deux scénarios k6 et une observabilité centralisée

- **Statut :** Acceptée
- **Date :** 2026-10-07
- **Décideurs :** Projet MGL870

## Contexte

La question de recherche porte sur l’effet du volume de charge utile. Il faut donc comparer un appel individuel et une ingestion par lot, tout en observant simultanément la latence, le débit, les erreurs et les ressources consommées.

## Décision

Utiliser deux scripts k6 : `load_test.js` pour un tick par requête et `load_test_batch.js` pour 500 ticks par requête. Les scénarios utilisent un exécuteur `ramping-arrival-rate`. Les résultats k6 sont exportés en JSON vers `results/`, puis envoyés à Prometheus. cAdvisor et `docker-metrics` alimentent les métriques de ressources; Grafana fournit les tableaux de bord et les captures.

## Options considérées

1. Mesurer uniquement des appels unitaires.
2. Mesurer uniquement des lots volumineux.
3. Comparer les deux tailles avec une télémétrie applicative et système commune.

## Justification

La troisième option permet de tester l’hypothèse d’un point de bascule lié à la taille du payload. Elle relie les résultats applicatifs aux ressources plutôt que de limiter l’analyse à la latence observée par le client.

## Conséquences

Le dispositif produit une analyse plus riche, mais les deux scénarios ne couvrent pas toutes les tailles intermédiaires. La conclusion sur le seuil de bascule doit donc être formulée comme une borne entre les scénarios observés, et non comme un seuil continu précisément identifié.

## Preuves attendues

Les scripts k6, les fichiers JSON, les dashboards et les captures Grafana rendent les scénarios et les observations reproductibles.
