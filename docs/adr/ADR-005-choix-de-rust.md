# ADR-005 : Utiliser Rust pour les serveurs évalués

- **Statut :** Acceptée
- **Date :** 2026-10-16
- **Décideurs :** Projet MGL870

## Contexte

Le projet cherche à isoler autant que possible le coût des protocoles, de la sérialisation et du transport. Le langage d’implémentation peut introduire du bruit par la gestion mémoire, le ramasse-miettes, l’exécution ou les bibliothèques disponibles.

## Décision

Implémenter les quatre serveurs dans le même projet Rust, en utilisant Axum pour REST, async-graphql pour GraphQL, jsonrpsee pour JSON-RPC et tonic/prost pour gRPC.

## Options considérées

1. Utiliser un langage différent pour chaque protocole.
2. Utiliser un même langage système pour les quatre variantes.
3. Utiliser un langage géré avec ramasse-miettes.

## Justification

Un langage commun réduit une source de variation entre les variantes. Rust fournit une exécution native sans ramasse-miettes et dispose de bibliothèques adaptées aux quatre interfaces étudiées. Ce choix ne supprime pas tous les biais d’implémentation, mais il évite de comparer simultanément des langages et des protocoles.

## Conséquences

La comparaison gagne en contrôle expérimental et en cohérence d’outillage. En contrepartie, les résultats ne se généralisent pas automatiquement aux implémentations Java, Go, C#, JavaScript ou à d’autres bibliothèques Rust. Le langage devient une constante expérimentale, pas une variable étudiée.

## Preuves disponibles

Le code source, `Cargo.toml`, `Cargo.lock`, `Dockerfile` et les modules des quatre serveurs permettent de vérifier que les variantes sont construites dans le même environnement Rust.
