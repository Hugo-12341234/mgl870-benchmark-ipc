# ADR-009 : Répliquer un artefact commun dans quatre conteneurs isolés

- **Statut :** Acceptée
- **Date :** 2026-11-19
- **Décideurs :** Projet MGL870

## Contexte

La comparaison doit éviter deux biais opposés. Exécuter les quatre protocoles dans un seul processus soumis à une seule limite CPU introduirait de la contention entre eux et empêcherait d’attribuer clairement les ressources à une variante. Développer quatre applications entièrement indépendantes réduirait cette contention, mais multiplierait les différences de code, de modèle, de compilation et d’image Docker.

L’architecture doit donc isoler les ressources de chaque protocole tout en conservant autant que possible le même artefact logiciel et le même chemin de traitement.

## Décision

Construire un seul binaire Rust et une seule image Docker contenant les quatre adaptateurs REST, GraphQL, JSON-RPC et gRPC ainsi que le modèle commun `Tick`. Répliquer cette image dans quatre conteneurs Docker distincts. Le générateur dirige chaque scénario vers un conteneur dédié au protocole mesuré : `server-rest`, `server-graphql`, `server-jsonrpc` ou `server-grpc`.

Chaque conteneur démarre le même binaire et expose donc les adaptateurs compilés, mais seul l’adaptateur ciblé reçoit la charge expérimentale. Les adaptateurs inutilisés restent inactifs. Chaque réplique reçoit sa propre limite de `0,25` vCPU et de 512 MiB et possède ses propres métriques de conteneur.

## Options considérées

1. Exécuter les quatre protocoles dans un seul conteneur et partager une limite de ressources.
2. Développer et construire quatre applications et quatre images indépendantes.
3. Construire un artefact commun et le répliquer dans quatre conteneurs isolés.
4. Construire quatre binaires spécialisés à partir d’un noyau commun, chacun ne contenant qu’un adaptateur.

## Justification

La troisième option contrôle mieux les variables que quatre applications indépendantes : version du compilateur, dépendances partagées, modèle de données, traitement de succès, image de base et options de compilation restent identiques. Elle isole simultanément les budgets CPU, mémoire et réseau, contrairement à un processus partagé. Les métriques peuvent ainsi être attribuées à un conteneur et à un protocole précis.

La quatrième option aurait supprimé les adaptateurs inactifs de chaque conteneur, mais aurait introduit plusieurs cibles de compilation et un risque de divergence entre les artefacts. Dans ce benchmark minimal, le faible coût de listeners inactifs et de code non sollicité est accepté comme compromis pour maximiser la symétrie des répliques.

## Conséquences

Les quatre variantes partagent la même base logicielle et le même environnement de construction, ce qui renforce la validité interne. Le redémarrage et la limitation des répliques peuvent être appliqués uniformément. Les diagrammes de composants et de déploiement correspondent directement au code et à Docker Compose.

En contrepartie, les conteneurs ne représentent pas quatre images minimales de production : chaque binaire contient des bibliothèques et des listeners qui ne sont pas sollicités dans trois des quatre rôles. Leur coût de repos est symétrique, mais il n’est pas nul. Les résultats portent donc sur cette architecture expérimentale commune et non sur la meilleure optimisation possible de chaque protocole.

## Preuves disponibles

`src/main.rs` assemble les quatre adaptateurs; `Dockerfile` construit un seul binaire et une seule image; `docker-compose.yml` réplique cette image sous quatre services avec des limites identiques. Les diagrammes `docs/figures/components.puml` et `docs/figures/architecture.puml`, les métriques par conteneur et les manifestes de la campagne officielle rendent cette décision vérifiable.
