# Utiliser First Bricks sur Windows

Windows 11 x64 : installer **Docker Desktop AMD64**, puis ouvrir Docker Desktop. Si Docker propose WSL 2, terminer son installation et redémarrer Windows si demandé. Attendre que le moteur Docker soit démarré. Railway et un abonnement d’hébergement ne sont pas nécessaires.

## Première ouverture

1. Télécharger la dernière archive `downloads/First-Bricks.zip` depuis GitHub.
2. Clic droit sur le ZIP → **Extraire tout**. Ne pas lancer les fichiers depuis l’aperçu du ZIP.
3. Ouvrir le dossier extrait `First-Bricks` contenant `compose.yaml` et `Dockerfile`.
4. Double-cliquer sur **Demarrer-First-Bricks.cmd**. Ce script fourni dans les sources vérifie Docker, construit l’application et l’ouvre dans le navigateur. L’accès Internet est nécessaire pour télécharger les dépendances et images la première fois; cela peut prendre plusieurs minutes. Si Windows affiche un avertissement de provenance, vérifier le fichier et son origine avant de décider de l’exécuter; il ne demande pas de privilèges administrateur.
5. Se connecter sur **http://localhost:4000** : utilisateur **admin**, mot de passe **local-first-bricks-2026**.

Le conteneur est lié à l’adresse locale `127.0.0.1` : cette configuration est réservée à votre ordinateur. La release locale utilise HTTP et un cookie compatible avec HTTP. Les réglages HTTPS et secrets obligatoires de la release Railway restent actifs dans la cible de production.

## Si le double-clic ne fonctionne pas

Dans l’Explorateur, ouvrir le dossier contenant `compose.yaml`, cliquer dans la barre d’adresse, taper `powershell` et appuyer sur Entrée. Exécuter :

```powershell
docker compose up --build -d
```

Ouvrir ensuite http://localhost:4000. Si la page ne s’affiche pas après la fin de la compilation :

```powershell
docker compose ps
docker compose logs --tail 50 app
```

Si le port 4000 est déjà occupé par une ancienne tentative `first-bricks-local`, l’arrêter avec `docker stop first-bricks-local`. Cela ne supprime pas ses données. Si le port est occupé par un autre programme, identifier ce programme avant de l’arrêter.

## Utilisation

- Importer `examples/inventaire-cfb.bsx` dans Canada et `examples/inventaire-ufb.bsx` dans États-Unis.
- Importer `examples/reception-vendor.bsx` comme réception vendor.
- Saisir les attributions CFB et UFB, puis enregistrer avant de télécharger les deux BSX.
- La compatibilité avec les inventaires réels Altreus reste à valider. Les exemples sont synthétiques.

## Arrêter et rouvrir

Dans le même dossier PowerShell :

```powershell
docker compose stop
docker compose start
```

Pour rouvrir, vous pouvez aussi relancer `Demarrer-First-Bricks.cmd`. Docker Desktop doit être démarré. Sans modification du projet, les couches de compilation sont réutilisées.

## Mettre à jour l’application

Télécharger le nouveau ZIP, l’extraire dans un nouveau dossier puis lancer `Demarrer-First-Bricks.cmd` de ce nouveau dossier. Docker Compose reconstruit l’image et remplace le conteneur du projet `first-bricks`; le volume nommé `first-bricks-data` est réutilisé. Garder Docker Desktop ouvert et attendre la fin de la construction avant de rouvrir la page. Ne pas supprimer le volume pour effectuer une mise à jour.

La limite d’import BSX est maintenant de **50 Mo**. Une sélection plus grosse est signalée dans le formulaire avant l’envoi. L’import d’un gros inventaire peut prendre plusieurs secondes; le bouton affiche « Importation en cours… ».

## Données conservées sur votre PC

Les données se trouvent dans le volume Docker nommé **first-bricks-data**; elles persistent après l’arrêt et la recréation du conteneur. Ne supprimez pas ce volume dans Docker Desktop, n’utilisez pas `docker compose down -v`, et ne réinitialisez pas Docker sans sauvegarde. Supprimer le dossier des sources ne sauvegarde ni ne supprime ce volume.

Pour sauvegarder, arrêter l’application puis, dans le dossier du projet :

```powershell
docker compose stop
docker compose cp app:/data/first_bricks.dets ./first-bricks-sauvegarde.dets
docker compose start
```

Conserver la sauvegarde en lieu sûr. Pour restaurer une sauvegarde existante avec le conteneur présent, arrêter le service, copier le fichier vers son emplacement puis redémarrer :

```powershell
docker compose stop
docker compose cp ./first-bricks-sauvegarde.dets app:/data/first_bricks.dets
docker compose start
```

La restauration remplace les données courantes : les sauvegarder avant cette opération. Les fichiers `*.dets` sont des données métier; ne pas les publier sur GitHub.

## Limites de validation

La release locale, le démarrage Docker Compose, les imports, les exports et la persistance sont vérifiés sur le moteur Docker Linux de développement. Le script `.cmd` est fourni pour Windows, mais n’a pas été exécuté sur un PC Windows dans cet environnement. En cas d’erreur, transmettre le message affiché pour poursuivre le diagnostic.
