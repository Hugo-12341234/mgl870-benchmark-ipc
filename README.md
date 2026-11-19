# MGL870 — Benchmark de protocoles IPC

Ce dépôt compare REST, GraphQL, JSON-RPC et gRPC pour une charge d’ingestion
minimale en Rust. Deux scénarios sont mesurés : un tick par requête et un lot
de 500 ticks.

## Exécuter la campagne reproductible

Prérequis : Docker Desktop doit être démarré et PowerShell doit pouvoir appeler
`docker compose`.

Valider d’abord le banc d’essai avec deux pilotes de 30 secondes :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_all_benchmarks.ps1 -Quick
```

Lancer ensuite les cinq répétitions de chacun des deux scénarios :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_all_benchmarks.ps1
```

La commande officielle produit un nouveau répertoire horodaté sous `results/`.
Chaque scénario et chaque run possède son propre sous-répertoire. Le dossier
`summary/` contient les tableaux consolidés et `screenshots/` reçoit les
captures représentatives. Grafana et Prometheus restent actifs à la fin :

- Grafana : <http://localhost:3000>
- Prometheus : <http://localhost:9090>

Le protocole détaillé, les critères de validation et la stratégie de captures
sont décrits dans [docs/benchmark-rerun.md](docs/benchmark-rerun.md).

Le rapport du projet est disponible dans [docs/REPORT.md](docs/REPORT.md).
