# ADR-006 : Définir des profils de charge soutenue avec k6

- **Statut :** Acceptée
- **Date :** 2026-10-16
- **Décideurs :** Projet MGL870

## Contexte

La question de recherche porte sur le comportement des protocoles lorsque la taille du payload et la pression CPU augmentent. Une charge trop faible ne ferait pas apparaître les différences de capacité; une charge instantanée ou uniquement fondée sur un nombre fixe de VUs ne permettrait pas de distinguer clairement la cadence offerte, l’accumulation de latence et la saturation soutenue.

## Décision

Utiliser l’exécuteur k6 `ramping-arrival-rate` avec deux profils déterministes :

- scénario unitaire : rampe de 0 à 2 000 req/s sur 3 min, puis à 4 000 req/s sur 3 min et à 6 000 req/s sur 4 min;
- scénario batch : rampe de 0 à 100 req/s sur 1 min, puis à 500 req/s sur 2 min, suivie d’un plateau à 500 req/s pendant 4 min.

Le palier final batch reste donc à 500 req/s pendant quatre minutes après la montée. Chaque scénario préalloue au maximum `4 000` VUs pour l’unitaire et `1 500` VUs pour le batch.

Les cibles sont définies **par protocole**. Les quatre scénarios s’exécutant en parallèle, la cible agrégée maximale atteint donc 24 000 req/s en unitaire et 2 000 req/s en batch. Ces nombres sont des cadences offertes, pas des débits garantis : le débit servi et les itérations abandonnées sont mesurés séparément.

## Options considérées

1. Utiliser un nombre fixe de VUs, avec une cadence dépendante des temps de réponse.
2. Utiliser une charge constante sans montée progressive.
3. Utiliser un pic court.
4. Utiliser une cadence d’arrivée progressive suivie d’un plateau soutenu.

## Justification

La quatrième option sépare la charge demandée de la vitesse à laquelle les réponses reviennent. `ramping-arrival-rate` tente de démarrer les itérations selon la cadence prévue; lorsqu’il ne peut plus le faire avec les VUs disponibles, k6 comptabilise explicitement les itérations abandonnées. Cette propriété rend la limite de capacité visible sans confondre une absence d’erreur applicative avec l’exécution de toute la charge demandée.

Les cibles de 6 000 req/s par protocole en unitaire et de 500 req/s par protocole en batch ne sont pas des prévisions de production ni des SLO. Les exécutions préliminaires ont permis de vérifier qu’elles traversaient une zone allant du fonctionnement stable à la saturation sur l’hôte disponible. La montée progressive montre le moment où la dégradation apparaît; le plateau batch de quatre minutes vérifie qu’elle persiste et ne constitue pas seulement un transitoire. Les durées de 10 et 7 minutes offrent plusieurs fenêtres de télémétrie tout en restant répétables cinq fois.

Les plafonds de VUs protègent l’hôte et rendent l’incapacité à suivre la cadence mesurable par `dropped_iterations`. Les augmenter indéfiniment aurait déplacé davantage de file d’attente dans le générateur et augmenté son empreinte mémoire sans transformer la cible en capacité réellement servie.

## Conséquences

Les profils mesurent une capacité sous charge soutenue, et non un comportement de rafale, une capacité maximale absolue ou un seuil continu exact. Les cadences doivent toujours être distinguées du débit effectivement servi. Leur niveau dépend de l’hôte, de la limite de `0,25` vCPU, des bibliothèques et du nombre de VUs; une autre plateforme devrait recalibrer la charge tout en conservant le principe de traverser la saturation. Le choix de deux tailles de payload encadre le point de bascule entre 1 et 500 ticks, mais ne le localise pas à l’intérieur de cet intervalle.

## Preuves disponibles

Les scripts k6, les dix résumés, les dix exports Prometheus, les manifestes et les captures représentatives documentent les profils effectivement exécutés. Les itérations abandonnées sont conservées par scénario comme indicateur de pression sur l’injecteur et le système.
