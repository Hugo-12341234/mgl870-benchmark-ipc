# MGL870 — Benchmark de protocoles IPC

Ce dépôt étudie une décision architecturale : dans quelles conditions le gain
d’efficacité de gRPC justifie-t-il son coût d’opérabilité et de couplage par
rapport à REST, GraphQL et JSON-RPC? Les quatre interfaces sont implémentées en
Rust et évaluées sous une même limite de `0,25` vCPU avec deux charges : un tick
par requête et un lot de 500 ticks.

## Résultat principal

La campagne officielle du 19 novembre 2026 comprend cinq répétitions par
charge et passe 75 contrôles d’intégrité sur 75. Elle montre un point de bascule
plutôt qu’un protocole universellement supérieur :

| Charge | Meilleur résultat observé | Résultat déterminant |
| --- | --- | --- |
| 1 tick/requête | REST | 3 163,5 req/s et p99 de 1 024,8 ms en moyenne |
| 500 ticks/requête | gRPC | 184 455 ticks/s en moyenne, pic moyen de 251 797 ticks/s et p99 de 266,2 ms |

Le rapport distingue les observations, les interprétations causales et les
coûts architecturaux qualitatifs. Les valeurs ne constituent pas un classement
universel; elles soutiennent une décision conditionnelle dans le contexte
expérimental documenté.

## Exécuter la campagne reproductible

Prérequis : Docker Desktop doit être démarré et PowerShell doit pouvoir appeler
`docker compose`.

Valider d’abord les contrats et les comportements fonctionnels des quatre
interfaces :

```powershell
cargo test
```

Valider ensuite le banc d’essai avec deux pilotes de 30 secondes :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_all_benchmarks.ps1 -Quick
```

Lancer ensuite les cinq répétitions de chacun des deux scénarios :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_all_benchmarks.ps1
```

La commande officielle produit un nouveau répertoire horodaté sous `results/`.
Chaque scénario et chaque run possède son propre sous-répertoire. Le dossier
`summary/` contient les tableaux consolidés ainsi que le rapport de validation;
`screenshots/` est préparé pour les captures représentatives. Grafana et
Prometheus restent actifs à la fin :

- Grafana : <http://localhost:3000>
- Prometheus : <http://localhost:9090>

Le protocole détaillé, les critères de validation et la stratégie de captures
sont décrits dans [docs/benchmark-rerun.md](docs/benchmark-rerun.md). Le rapport
de validation de la campagne officielle est disponible dans
[results/rerun_20261119-104900/summary/validation_report.md](results/rerun_20261119-104900/summary/validation_report.md).

Le rapport du projet est disponible dans [docs/REPORT.md](docs/REPORT.md).
La campagne officielle et l’archive historique sont décrites dans
[results/README.md](results/README.md).

## Organisation du dépôt

- `src/` et `proto/` : serveurs Rust et contrat Protocol Buffers;
- `tests/` et les modules `#[cfg(test)]` de `src/` : charges k6, tests Rust,
  orchestration, consolidation et validation;
- `grafana/` et `prometheus.yml` : observabilité reproductible;
- `results/rerun_20261119-104900/` : données numériques officielles;
- `docs/screenshots/rerun/` : captures des runs représentatifs;
- `docs/adr/` et `docs/figures/` : décisions et vues architecturales;
- `docs/REPORT.md` : livrable final autonome.
