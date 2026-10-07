# ADR-003 : Imposer une limite commune de 0,25 vCPU

- **Statut :** Acceptée
- **Date :** 2026-10-07
- **Décideurs :** Projet MGL870

## Contexte

Les tests initiaux étaient susceptibles d’être limités par la virtualisation réseau de l’hôte plutôt que par le coût de traitement des serveurs. Une machine non contrainte aurait aussi pu masquer les différences de parsing et de désérialisation.

## Décision

Limiter chacun des quatre conteneurs évalués à `0,25` vCPU et 512 MiB de mémoire dans Docker Compose. La consommation CPU est suivie par cAdvisor et les métriques Docker.

## Options considérées

1. Ne pas limiter les ressources.
2. Limiter les conteneurs à une capacité élevée.
3. Appliquer une limite stricte et identique aux quatre variantes.

## Justification

La troisième option crée une saturation computationnelle contrôlée et rend les coûts relatifs plus visibles. La même limite évite de favoriser un protocole par une allocation supérieure.

## Conséquences

La configuration est représentative d’un environnement fortement contraint, mais elle n’est pas une représentation universelle des déploiements de production. Les effets de l’hôte Windows, de WSL2/Hyper-V et de la virtualisation réseau doivent rester discutés comme menaces à la validité.

## Preuves attendues

Les fichiers `docker-compose.yml` et les captures Grafana doivent montrer le plafonnement proche de 25 % de la capacité exposée à chaque conteneur.
