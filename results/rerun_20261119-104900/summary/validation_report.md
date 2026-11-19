# Benchmark suite validation

- Suite: `rerun_20261119-104900`
- Status: **PASS**
- Checks: 75/75 passed
- Runs: 10/10 present
- Git commit: `b94ba5352de06c167473d725d4a64bc6d0368223`
- Docker server: `28.0.4`

| Workload | Run | Duration (s) | Completed | Dropped | Dropped | Semantic failures | Error protocols | Missing telemetry |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| batch | 1 | 431.2 | 429599 | 206358 | 32.45% | 0 | 0 | 0 |
| batch | 2 | 431.929 | 438395 | 197558 | 31.06% | 0 | 0 | 0 |
| batch | 3 | 430.692 | 429941 | 206010 | 32.39% | 0 | 0 | 0 |
| batch | 4 | 429.846 | 433046 | 202854 | 31.9% | 0 | 0 | 0 |
| batch | 5 | 431.136 | 412011 | 223940 | 35.21% | 0 | 0 | 0 |
| individual | 1 | 601.508 | 6254316 | 1395806 | 18.25% | 0 | 0 | 0 |
| individual | 2 | 601.653 | 6464789 | 1213625 | 15.81% | 0 | 0 | 0 |
| individual | 3 | 601.62 | 6508437 | 1170688 | 15.25% | 0 | 0 | 0 |
| individual | 4 | 601.399 | 6433540 | 1236742 | 16.12% | 0 | 0 | 0 |
| individual | 5 | 601.719 | 6283475 | 1395069 | 18.17% | 0 | 0 | 0 |
