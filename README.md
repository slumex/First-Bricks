# Altreus Inventory Optimizer (AIO)

[Télécharger le ZIP des sources](https://github.com/slumex/First-Bricks/raw/refs/heads/main/downloads/AIO.zip) · [Résultats de validation](VALIDATION.md)

Application Elixir/Phoenix en français pour répartir une réception vendor entre **Canada First Bricks (CFB)** et **USA First Bricks (UFB)**. Leurs plateformes sont **Altreus CFB** et **Altreus UFB**.

## Windows avec Docker Desktop

Consulter [le guide Windows](WINDOWS.md). Extraire le ZIP puis lancer `Demarrer-AIO.cmd`, ou exécuter `docker compose up --build -d` dans le dossier du projet. Ouvrir http://localhost:4000 (identifiant `admin`, mot de passe `local-first-bricks-2026`). Les données restent dans le volume Docker `first-bricks-data`.

## Démarrage local

Prérequis : Elixir 1.18 / Erlang OTP 27 (les versions utilisées dans le Dockerfile), Git. Aucun Node.js, service de base de données ou compte Altreus requis.

```sh
mix local.hex --force
mix local.rebar --force
mix deps.get
mix test
mix phx.server
```

Ouvrir le port 4000 de votre machine. En développement uniquement : utilisateur `admin`, mot de passe `change-me`. Ne pas exposer le mode développement sur Internet. Le mode production refuse de démarrer sans ses secrets.

## Parcours de démonstration

1. Importer `examples/inventaire-cfb.bsx` dans Canada, puis `examples/inventaire-ufb.bsx` dans États-Unis.
2. Importer `examples/reception-vendor.bsx` comme réception vendor.
3. La brique 3001 neuve rouge est **présente à zéro chez CFB** et présente à 8 chez UFB. La 3002 usagée blanche est **absente chez CFB**, **présente à zéro chez UFB**. La 3020 neuve noire est présente à 12 chez CFB et absente chez UFB.
4. Attribuer, par exemple, respectivement `5/5`, `0/4`, `1/2` à CFB/UFB. Enregistrer. Les deux quantités peuvent être nulles; une attribution partielle est conservée avec son reste.
5. Télécharger les deux BSX. Ils reflètent la dernière répartition **enregistrée**, pas les champs en cours d’édition. Un export sans attribution est un inventaire XML vide.
6. Les réceptions restent accessibles au tableau de bord. Chaque nouvel import de stock devient la référence courante; les originaux antérieurs restent téléchargeables dans l’historique. Les réceptions conservent également leur XML source sur disque.

Les stocks affichés sont ceux des derniers imports au moment de la consultation. Enregistrer ou exporter une réception ne modifie jamais ces stocks et ne pousse aucune donnée vers Altreus. Les exports sont des **ajouts correspondant à la réception**, et non des inventaires complets. Ne pas réimporter plusieurs fois le même export dans Altreus sans vérifier son mode de fusion.

## Bouton « Attribuer les stocks »

Dans une réception, ce bouton remplit les deux champs de chaque ligne avec une proposition : toute la quantité reçue va à la boutique dont le stock courant est le plus bas. En cas d’égalité, CFB est prioritaire, notamment lorsque les deux stocks sont à zéro. Un lot absent compte pour zéro dans ce calcul, mais reste affiché « Absent ». Le rapprochement utilise toujours le type, l’identifiant, la couleur et l’état.

Importer les deux inventaires avant d’utiliser ce bouton; un inventaire importé vide est autorisé. La proposition est calculée à partir des derniers imports et remplace les saisies du formulaire. Elle ne modifie ni les stocks ni la répartition enregistrée : vous pouvez l’ajuster, puis cliquer sur **Enregistrer la répartition**. Les exports utilisent toujours les quantités enregistrées. Un clic depuis une page dont la révision est périmée est rejeté.

## Format BSX et limites de compatibilité

L’adaptateur prend en charge un sous-ensemble BrickStore XML UTF-8 : `BrickStoreXML/Inventory/Item`, avec `ItemTypeID`, `ItemID`, `ColorID`, `Condition` (`N` neuf / `U` usagé) et `Qty` entier positif ou nul, au maximum 2 147 483 647 par ligne. Types admis : P, M, S, B, G, I, O, C. La clé de rapprochement exacte est **type + identifiant + couleur + état**; aucune correspondance approximative. Les doublons de cette clé sont additionnés. L’ordre des lots est déterministe.

Les exports préservent les champs reconnus `ItemName`, `ColorName`, `Price`, `Comments`, `Remarks` provenant de la réception; les autres champs XML ne sont pas réexportés. En cas de doublons, les métadonnées de la première ligne sont utilisées. Le XML d’origine reste conservé. Les DTD/entités sont interdites; les fichiers sont limités à 50 Mo. Un inventaire vide est autorisé, une réception vide est rejetée.

**Compatibilité Altreus non certifiée.** Les exemples sont synthétiques. Avant usage réel, fournir des fichiers anonymisés exportés d’Altreus CFB, d’Altreus UFB et du vendor. Vérifier les identifiants de types/couleurs, les états, l’encodage, les champs métier et les règles d’import (addition/remplacement). Faire un essai contrôlé sur quelques lots puis comparer les quantités. Adapter l’import/export et ajouter les fixtures correspondantes dans une tâche de code si le dialecte diffère. Aucun connecteur API Altreus n’est inclus.

## Persistance et concurrence

Un GenServer sérialise les modifications et synchronise une table Erlang DETS sur disque après chaque import et sauvegarde. Les attributions de toutes les lignes sont validées avant une écriture unique. Un numéro de révision rejette les sauvegardes d’une page périmée; recharger avant de réessayer. Une erreur de validation conserve la répartition enregistrée et réaffiche les champs soumis.

Données locales dans `data/first_bricks.dets`, tests dans `tmp/test-data/`. Aucun nettoyage automatique des historiques : surveiller la taille du volume. **Une seule instance, un seul processus propriétaire du fichier et un volume local persistant**. Ce stockage convient à une petite équipe; pour plusieurs réplicas ou des volumes importants, migrer vers PostgreSQL. Les imports sont conservés intégralement en mémoire et sur disque; ce n’est pas une plateforme de gros volumes.

Sauvegarder le volume régulièrement. Pour une copie cohérente du fichier DETS, arrêter le service avant la copie/snapshot; restaurer le fichier complet sur le volume puis redémarrer avec la même version de l’application. Tester périodiquement la restauration. Les inventaires exportés peuvent contenir des données métier; ne pas les ajouter au dépôt.

## Déploiement Railway

Le dépôt contient un Dockerfile à plusieurs étapes et `railway.toml`. Aucun déploiement n’est effectué automatiquement par ce livrable.

1. Créer un service Railway depuis ce dépôt et utiliser le Dockerfile.
2. Ajouter **un volume persistant monté sur `/data`**. Régler `DATA_DIR=/data`. Le point d’entrée prépare les droits de `/data`, puis exécute l’application sous l’UID non privilégié **10001**. Si votre politique impose un UID au démarrage, préparer les permissions du volume pour cet UID. Ne pas compter sur le système de fichiers éphémère du service.
3. Définir `MIX_ENV=prod` si nécessaire, `PHX_HOST` au nom de domaine public sans schéma, `APP_USERNAME` à l’identifiant choisi, `APP_PASSWORD` à un secret aléatoire d’au moins 16 caractères, `SECRET_KEY_BASE` à une valeur aléatoire d’au moins 64 caractères (génération locale : `openssl rand -hex 64`). Saisir les secrets dans les variables Railway, jamais dans Git. Railway injecte `PORT`.
4. Conserver **un seul réplica**. La configuration active le healthcheck public `/health`. Tout écran, import, original et export exige HTTP Basic Auth. Le navigateur mémorise ces identifiants; fermer la session du navigateur ou effacer les identifiants HTTP pour changer d’utilisateur. Il n’y a pas de gestion de comptes ni de rôles individuels.
5. Activer le domaine HTTPS. En production, Phoenix redirige vers HTTPS en s’appuyant sur `X-Forwarded-Proto` du proxy Railway; ne pas exposer directement le serveur sans proxy de confiance. Les cookies de session sont sécurisés; les formulaires utilisent un jeton CSRF. Le healthcheck ne divulgue que `ok`.
6. Après déploiement : constater la réussite du healthcheck, vérifier le refus d’accès sans identifiants, importer les exemples, enregistrer une répartition et télécharger les deux exports. Redémarrer le service et confirmer que les données sont conservées. Vérifier aussi une restauration de sauvegarde avant l’usage métier.

Le healthcheck vérifie le processus HTTP; il ne constitue pas un test de bout en bout du volume. Le déploiement Railway et la persistance après redéploiement réel restent à valider dans votre compte.

### Conteneur local de production

```sh
docker build -t first-bricks .
docker volume create first-bricks-data
# Fournir ces variables au shell, sans les inscrire dans le dépôt :
# SECRET_KEY_BASE, APP_PASSWORD, PHX_HOST, APP_USERNAME
# Utiliser un proxy HTTPS de confiance qui transmet X-Forwarded-Proto.
docker run --rm -p 4000:4000 -v first-bricks-data:/data \
  -e SECRET_KEY_BASE -e APP_PASSWORD -e PHX_HOST -e APP_USERNAME first-bricks
```

## Développement et vérifications

```sh
mix format --check-formatted
mix test
MIX_ENV=prod mix compile --warnings-as-errors
MIX_ENV=prod mix release
```

Les tests couvrent le parseur XML, les quantités invalides, les clés de rapprochement, les doublons, la distinction absent/zéro, les attributions partagées et partielles, les conflits de révision, l’atomicité en cas d’erreur, les deux exports, l’historique, le redémarrage du stockage, l’authentification, le CSRF et le parcours HTTP import/sauvegarde/export.

Les tâches de développement cloud utilisent le checkout existant, sans créer de worktree sauf demande explicite. Ne jamais lancer les tests avec `DATA_DIR` pointant sur des données réelles. `.env` est ignoré mais n’est pas chargé automatiquement par l’application.

### Test HTTP réel et redémarrage

Le script Python standard `scripts/smoke.py` importe les exemples et vérifie aussi les exports et les rejets d’écriture. Il **ajoute des données de démonstration** : l’exécuter sur une instance de test. Fournir `SMOKE_USERNAME` et `SMOKE_PASSWORD` dans l’environnement du shell, puis :

```sh
python3 scripts/smoke.py --base-url https://votre-instance-de-test
# Redémarrer le service, puis réutiliser le même fichier d’état local :
python3 scripts/smoke.py --base-url https://votre-instance-de-test --check-state
```

Pour un conteneur de production local sans terminaison TLS, définir uniquement pour ce test `SMOKE_FORWARDED_PROTO=https` et utiliser une URL `http://127.0.0.1:PORT`. Le script vérifie aussi que les requêtes sans cet en-tête sont redirigées vers HTTPS, sauf `/health`. Cette simulation ne remplace pas la vérification du domaine HTTPS Railway.

Les résultats de validation de cette livraison se trouvent dans `VALIDATION.md`.

## Recréer l’archive

```sh
python3 scripts/package.py
```

Le ZIP et son empreinte SHA-256 sont créés à côté du répertoire du projet. L’archive contient les sources, le verrou de dépendances, les tests, les exemples BSX et les instructions. Les dépendances compilées, données DETS, secrets et métadonnées Git sont exclus.
