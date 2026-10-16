# ADR-006 : Définir des profils de charge soutenue avec k6

- **Statut :** Acceptée
- **Date :** 2026-10-16
- **Décideurs :** Projet MGL870

## Contexte

La question de recherche porte sur le comportement des protocoles lorsque la taille du payload et la pression CPU augmentent. Un pic instantané ne permettrait pas de distinguer une variation transitoire d’une saturation soutenue.

## Décision

Utiliser l’exécuteur k6 `ramping-arrival-rate` avec deux profils déterministes :

- scénario unitaire : 2 000 req/s pendant 3 min, 4 000 req/s pendant 3 min, puis 6 000 req/s pendant 4 min;
- scénario batch : 100 req/s pendant 1 min, puis 500 req/s pendant 2 min et 500 req/s pendant 4 min supplémentaires.

Le palier final batch reste donc à 500 req/s pendant six minutes. Les VUs sont préalloués au maximum (`4 000` pour l’unitaire et `1 500` pour le batch).

## Options considérées

1. Utiliser une charge constante sans montée progressive.
2. Utiliser un pic court.
3. Utiliser une montée progressive suivie d’un plateau soutenu.

## Justification

La montée progressive permet d’observer l’apparition de la dégradation. Le plateau prolongé rend la saturation mesurable dans le temps et permet de comparer les courbes Grafana. Les durées de 10 minutes pour l’unitaire et 7 minutes pour le batch offrent une fenêtre suffisante pour les paliers et la télémétrie, tout en restant répétables cinq fois.

## Conséquences

Les profils mesurent une capacité sous charge soutenue, et non un comportement de rafale ou un seuil exact continu. Le choix de deux tailles de payload encadre le point de bascule entre 1 et 500 ticks, mais ne le localise pas à l’intérieur de cet intervalle.

## Preuves disponibles

Les scripts k6, les dix fichiers JSON, les captures Grafana et les ADRs documentent les profils effectivement exécutés. Les itérations abandonnées sont conservées comme indicateur de pression sur l’injecteur et le système.
