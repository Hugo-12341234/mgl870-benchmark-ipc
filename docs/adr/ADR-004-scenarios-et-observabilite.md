# ADR-004 : Utiliser deux scénarios k6 et une observabilité centralisée

- **Statut :** Acceptée
- **Date :** 2026-10-07
- **Décideurs :** Projet MGL870

## Contexte

La question de recherche porte sur l’effet du volume de charge utile. Un test limité aux appels unitaires pourrait favoriser les chemins dont le coût fixe est faible sans montrer le coût du traitement d’un document volumineux. À l’inverse, un test limité aux lots ne permettrait pas d’observer si le coût fixe d’un protocole spécialisé est amorti. Il faut donc comparer les deux régimes tout en observant simultanément la latence, le débit, les erreurs et les ressources consommées.

## Décision

Utiliser deux scripts k6 : `load_test.js` pour un tick par requête et `load_test_batch.js` pour 500 ticks par requête. Le lot de 500 constitue un contraste expérimental volontairement important : il amortit le coût fixe d’une requête sur plusieurs objets et rend visible le coût de traitement d’une charge utile volumineuse, tout en demeurant exécutable avec la mémoire et le générateur disponibles.

Les scénarios utilisent un exécuteur `ramping-arrival-rate` et un `testid` unique. Chaque run conserve un résumé k6, un export de ses séries Prometheus et un manifeste d’environnement. cAdvisor et `docker-metrics` alimentent les métriques de ressources; Grafana fournit les tableaux de bord et les captures représentatives.

## Options considérées

1. Mesurer uniquement des appels unitaires.
2. Mesurer uniquement des lots volumineux.
3. Comparer deux tailles fortement contrastées avec une télémétrie applicative et système commune.
4. Tester une série complète de tailles intermédiaires, par exemple 1, 10, 50, 100, 250 et 500 ticks.

## Justification

La troisième option permet de tester l’hypothèse d’un changement de compromis lié à la taille du payload dans le temps disponible pour le projet, tout en conservant cinq répétitions par scénario. La taille de 500 ticks n’est pas présentée comme une taille universelle ni comme une prévision exacte d’une charge financière de production. Elle sert à créer un régime où la sérialisation, le parsing et le volume transféré prennent une place beaucoup plus importante que pour un tick. La quatrième option aurait localisé plus finement le point de bascule, mais aurait multiplié la durée de campagne et réduit la profondeur des répétitions ou de l’observabilité.

La télémétrie commune relie les résultats applicatifs aux ressources plutôt que de limiter l’analyse à la latence observée par le client. Pour le scénario batch, le débit est exprimé à la fois en requêtes par seconde et en ticks par seconde afin d’éviter qu’un lot soit interprété comme une seule unité de travail utile.

## Conséquences

Le dispositif produit une analyse plus riche et permet de vérifier si le classement change entre les deux régimes. Il ne couvre toutefois pas les tailles intermédiaires. La conclusion sur le point de bascule doit donc être formulée comme une borne entre 1 et 500 ticks, et non comme un seuil continu précisément identifié. Une étude cherchant ce seuil devrait ajouter les tailles intermédiaires sans modifier les autres facteurs.

## Preuves attendues

Les scripts k6, les résumés, les exports Prometheus, les manifestes, les dashboards et les captures Grafana rendent les scénarios et les observations reproductibles.
