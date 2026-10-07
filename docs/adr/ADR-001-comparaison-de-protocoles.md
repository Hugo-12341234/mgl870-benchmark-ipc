# ADR-001 : Comparer quatre protocoles d’ingestion

- **Statut :** Acceptée
- **Date :** 2026-10-07
- **Décideurs :** Projet MGL870

## Contexte

Le projet doit étudier une décision architecturale mesurable concernant la communication inter-processus dans un scénario d’ingestion à haute fréquence. Une seule technologie ne permettrait pas d’observer les compromis entre interface orientée ressource, appel de procédure, requêtage dynamique, sérialisation textuelle et sérialisation binaire.

## Décision

Comparer REST, JSON-RPC, GraphQL et gRPC dans un même banc d’essai, avec un traitement applicatif minimal et deux tailles de charge utile : un tick unitaire et un lot de 500 ticks.

## Options considérées

1. Évaluer uniquement REST et gRPC.
2. Comparer les quatre protocoles retenus.
3. Ajouter d’autres technologies, comme WebSocket ou un broker de messages.

## Justification

La deuxième option couvre quatre compromis distincts tout en gardant un périmètre réalisable. REST fournit la baseline textuelle orientée ressource. JSON-RPC représente l’appel de procédure textuel. GraphQL représente une interface dynamique. gRPC représente l’appel de procédure fortement contractuel et binaire.

## Conséquences

La comparaison devient plus informative architecturalement, mais elle exige de contrôler les implémentations, les charges, les ressources et les métriques. Les conclusions restent limitées aux protocoles, bibliothèques et scénarios étudiés.

## Preuves attendues

Les résultats k6, les mesures Prometheus/cAdvisor et les captures Grafana doivent montrer l’effet de la taille du payload sur la latence, le débit et l’utilisation CPU.
