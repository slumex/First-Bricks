# Validation de la livraison

Exécution le 31 octobre 2026 dans l’environnement de développement cloud.

- Elixir 1.18 / Erlang OTP 27, image officielle verrouillée par digest dans le Dockerfile.
- `mix test` : **13 tests exécutés, 13 réussis**.
- `mix format --check-formatted` : réussi.
- `MIX_ENV=prod mix compile --warnings-as-errors` : réussi.
- Assemblage de la release OTP : réussi.
- Construction du Dockerfile complet avec vérification TLS : réussie.
- `mix hex.audit` : aucun paquet retiré ou avis de sécurité signalé pour les dépendances finales au moment de la vérification. Cela ne remplace pas les audits futurs.
- Parcours HTTP réel sur la release de production : import des trois exemples, stocks absent/zéro, sauvegarde partagée, rejet des dépassements et révisions périmées, téléchargement des deux BSX et des inventaires originaux.
- Accès aux pages et exports sans identifiants : refusé (401). POST sans jeton CSRF : refusé (403).
- Redémarrage puis remplacement du conteneur par une nouvelle image avec le même volume : réception, attributions, inventaires originaux et exports conservés.
- HTTP sans en-tête de proxy HTTPS : redirection 301 des écrans; `/health` reste disponible en HTTP (200).
- Secrets absents et mot de passe de production trop court : démarrage refusé.
- Mode production : exécution de l’application sous UID 10001; le point d’entrée prépare les permissions du volume avant d’abandonner les privilèges.

Les détails du format pris en charge, le démarrage local, les variables et le déploiement Railway sont dans `README.md`. Le script `scripts/smoke.py` permet de reproduire le parcours HTTP et la vérification après redémarrage.

## Ce qui reste à valider

- Compatibilité avec les fichiers réels Altreus CFB, Altreus UFB et vendor : les fixtures actuelles sont synthétiques.
- Déploiement dans un compte Railway, domaine HTTPS public, permissions du volume dans ce compte et conservation après redéploiement Railway.
- Restauration d’une sauvegarde réelle du volume, charge et volumes représentatifs du métier.

Aucun déploiement externe ni import dans Altreus n’a été effectué. La livraison contient les sources et les instructions; elle ne contient aucun secret, inventaire réel ou fichier de données DETS.
