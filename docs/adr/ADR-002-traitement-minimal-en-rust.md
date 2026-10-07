# ADR-002 : Isoler le coût de communication par un traitement minimal en Rust

- **Statut :** Acceptée
- **Date :** 2026-10-07
- **Décideurs :** Projet MGL870

## Contexte

Une logique métier, une base de données ou une persistance durable ajouteraient des coûts qui pourraient masquer les différences entre les protocoles. Le projet cherche d’abord à observer le coût de la frontière de communication et de la désérialisation.

## Décision

Implémenter les quatre variantes dans le même projet Rust, sans ramasse-miettes, sans base de données et sans logique métier. Chaque endpoint reçoit un tick ou un lot, le désérialise vers le modèle attendu et retourne un succès.

## Options considérées

1. Utiliser une application métier complète.
2. Utiliser un traitement minimal commun.
3. Comparer des applications différentes propres à chaque protocole.

## Justification

Le traitement minimal réduit les variables parasites et rend les écarts plus directement attribuables à la pile de communication. L’usage d’un même langage et d’un même modèle de données réduit également les différences d’environnement d’exécution.

## Conséquences

La validité interne de la comparaison est favorisée, mais la validité externe est limitée. Les résultats ne représentent pas la performance d’un système financier complet et ne couvrent pas les coûts d’une base de données, d’une validation métier ou d’une transaction.

## Preuves attendues

Les implémentations source, le modèle `Tick`, le contrat `tick.proto` et les scripts k6 permettent de vérifier que le traitement comparé est équivalent.
