# Captures Grafana

- [`rerun/individual_run_1/`](rerun/individual_run_1/) contient le run unitaire officiel `20261119-104900-individual-run1`.
- [`rerun/batch_run_1/`](rerun/batch_run_1/) contient le run batch officiel `20261119-104900-batch-run1`.
- [`archive/legacy_pre_validation/`](archive/legacy_pre_validation/) conserve les anciennes captures pour audit. Leurs courbes et classements restent comparables, mais leurs panneaux de latence déclaraient incorrectement des millisecondes au lieu de secondes.

Ces deux runs ont été sélectionnés par la règle médiane documentée dans
`results/rerun_20261119-104900/summary/representative_runs.md`. Les captures
illustrent les tendances temporelles. Les valeurs quantitatives du rapport
proviennent des résumés k6, des exports Prometheus et des CSV consolidés.
