# Protocole de réexécution des benchmarks

## Objectif

La campagne officielle comprend dix exécutions : cinq répétitions du scénario
unitaire et cinq répétitions du scénario par lots de 500 ticks. Le script alterne
les scénarios (`individual 1`, `batch 1`, etc.) afin de réduire l’effet d’une
dérive temporelle de l’hôte.

Chaque exécution redémarre les quatre serveurs, attend que les ports soient
disponibles, lance k6 avec un identifiant unique, laisse les dernières métriques
être envoyées, puis exporte les séries Prometheus du créneau exact du test.
Après les dix exécutions, la même commande consolide les résultats et lance les
75 contrôles d’intégrité de la suite.

## Avant la campagne

1. Fermer les applications lourdes et éviter les téléchargements, mises à jour
   ou autres charges importantes pendant toute la campagne.
2. Brancher l’ordinateur et désactiver temporairement la mise en veille.
3. Démarrer Docker Desktop et attendre que le moteur soit prêt.
4. Ne pas modifier le code, les profils k6 ou les limites Docker entre les runs.
5. Exécuter le pilote :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_all_benchmarks.ps1 -Quick
```

Le pilote doit terminer avec zéro échec de check et créer un dossier
`results/pilot_<horodatage>/` organisé par scénario et par run.

## Campagne officielle

Exécuter une seule fois :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_all_benchmarks.ps1
```

La durée prévue est d’environ 85 à 100 minutes, selon le temps de construction
initial. Le script crée automatiquement `results/rerun_<horodatage>/`; il refuse
d’écraser un dossier contenant déjà des résumés de benchmark.

Un code k6 `99` peut être attendu lorsqu’un seuil de saturation volontaire est
franchi. Le script l’accepte, mais refuse le run si un check sémantique échoue,
si un artefact manque ou si les métriques séparées d’un protocole sont absentes.

## Organisation des artefacts

```text
results/rerun_<horodatage>/
├── individual/
│   ├── run_1/
│   │   ├── k6_summary.json
│   │   ├── prometheus.json
│   │   └── manifest.json
│   └── run_2/ ... run_5/
├── batch/
│   ├── run_1/
│   │   ├── k6_summary.json
│   │   ├── prometheus.json
│   │   └── manifest.json
│   └── run_2/ ... run_5/
├── summary/
│   ├── per_run_results.csv
│   ├── consolidated_results.csv
│   ├── consolidated_results.md
│   ├── representative_runs.md
│   ├── validation_report.md
│   └── validation_report.json
└── screenshots/
    ├── individual/
    └── batch/
```

## Artefacts produits

Pour chaque run :

- `k6_summary.json` : compteurs et percentiles par protocole en millisecondes;
- `prometheus.json` : séries temporelles brutes, avec les latences en
  secondes comme elles sont stockées par le remote write k6;
- `manifest.json` : identifiant du test, période UTC, commit Git, état du
  dépôt, version Docker et caractéristiques de l’hôte.

Pour l’ensemble de la campagne :

- `summary/per_run_results.csv` : une ligne par scénario, répétition et protocole;
- `summary/consolidated_results.csv` et `summary/consolidated_results.md` : moyennes des cinq
  répétitions et étendue du p99;
- `summary/representative_runs.md` : run et `testid` à sélectionner pour les captures
  Grafana selon une règle déterministe.
- `summary/validation_report.md` et `summary/validation_report.json` : résultat
  lisible et résultat structuré des contrôles d’intégrité de la campagne.

Ces fichiers sont les preuves numériques principales. Les captures Grafana
servent à montrer la forme temporelle, la saturation et l’observabilité.

## Captures Grafana

Il n’est pas nécessaire d’insérer ou de refaire une capture pour chacun des dix
runs. Une stratégie plus claire et plus défendable est :

1. conserver les données k6, Prometheus et les manifestes des dix runs;
2. utiliser les runs indiqués dans `summary/representative_runs.md`; le script choisit,
   pour chaque scénario, le run dont la moyenne des p99 des quatre protocoles
   est la plus proche de la médiane des cinq moyennes de run;
3. sélectionner leur `testid` dans la variable du dashboard Grafana;
4. capturer pour chacun au minimum la latence p99, le débit utile, le CPU et le
   taux d’erreur/itérations abandonnées;
5. conserver les autres captures seulement en annexe si elles ajoutent une
   information réelle.

Les dashboards affichent les latences en secondes parce que Prometheus reçoit
les métriques temporelles k6 dans cette unité. Les résumés JSON k6 et les CSV
consolidés les expriment en millisecondes. Il ne faut donc pas comparer les
valeurs sans appliquer ce facteur de conversion.

## Après la campagne

1. Vérifier que `summary/consolidated_results.md` contient huit lignes : quatre
   protocoles pour chacun des deux scénarios, avec cinq runs par ligne.
2. Vérifier que chaque manifeste indique zéro échec sémantique.
3. Vérifier que chaque manifeste contient un compte de séries supérieur à zéro
   pour les latences, le débit, le CPU, la mémoire et le réseau. Le script refuse
   automatiquement un run si une de ces séries essentielles est vide.
4. Choisir les deux runs représentatifs avant de remplacer les figures et les
   tableaux du rapport.
5. Archiver le répertoire complet de la campagne avec la remise.

La commande de campagne exécute automatiquement cette validation. Pour la
relancer séparément sur une campagne existante :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\validate_benchmark_suite.ps1 -OutputDirectory rerun_<horodatage>
```

Le script vérifie les dix triplets d’artefacts, les checks sémantiques, les taux d’erreur, les métriques par protocole, la couverture Prometheus, les identifiants uniques, le commit, Docker et l’hôte. Il produit `summary/validation_report.md` et `summary/validation_report.json`.
