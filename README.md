# Network6

> Outil open source de monitoring réseau macOS — visualisez vos connexions en temps réel, style Little Snitch.

## Fonctionnalités

- 🔍 **Monitoring temps réel** des connexions réseau (style `top`)
- 🌍 **Géolocalisation** des serveurs distants (pays, ville, organisation)
- 🔗 **Résolution DNS inverse** avec cache
- 📋 **Informations détaillées** : application, PID, protocole, état, ports, utilisateur
- 🏷️ **Labels ports** : identification automatique des services (HTTPS, SSH, DNS...)
- 🎨 **Affichage coloré** avec codes ANSI
- 📦 **Architecture modulaire** : bibliothèque `Network6Core` réutilisable (CLI + future UI SwiftUI)

## Installation

```bash
git clone https://github.com/youruser/Network6.git
cd Network6
swift build -c release

# L'exécutable se trouve dans .build/release/network6
cp .build/release/network6 /usr/local/bin/
```

## Usage

```bash
# Lancer le monitoring (mode utilisateur)
network6

# Avec sudo pour voir toutes les connexions (recommandé)
sudo network6

# Rafraîchissement toutes les 5 secondes
network6 --refresh 5

# Filtrer par application
network6 --filter Safari

# Afficher uniquement les connexions établies
network6 --established

# Inclure les ports en écoute
network6 --listen

# Trier par pays
network6 --sort country

# Sans résolution DNS/GeoIP (plus rapide)
network6 --no-dns --no-geo
```

## Options

| Option | Description | Défaut |
|--------|-------------|--------|
| `--refresh, -r` | Intervalle de rafraîchissement (secondes) | 2.0 |
| `--filter, -f` | Filtrer par nom d'application | — |
| `--sort, -s` | Trier par : app, remote, port, state, country, pid | app |
| `--established` | Uniquement les connexions ESTABLISHED | false |
| `--listen` | Inclure les ports en LISTEN | false |
| `--no-dns` | Désactiver la résolution DNS inverse | false |
| `--no-geo` | Désactiver la géolocalisation | false |

## Architecture

```
Network6/
├── Sources/
│   ├── Network6Core/          # Bibliothèque partagée (réutilisable)
│   │   ├── Models/            # ConnectionInfo, GeoLocation
│   │   ├── Monitors/          # ConnectionMonitor (capture via lsof)
│   │   └── Resolvers/         # DNS, GeoIP, Process, PortLabels
│   └── Network6CLI/           # Application console temps réel
└── Tests/
    └── Network6CoreTests/     # Tests unitaires
```

`Network6Core` est conçu pour être importé par la future interface SwiftUI sans modification.

## Informations affichées

| Colonne | Description |
|---------|-------------|
| APPLICATION | Nom du processus |
| PID | Identifiant du processus |
| PROTO | TCP / UDP |
| STATE | ESTABLISHED, LISTEN, TIME_WAIT... |
| LOCAL | Adresse et port local |
| REMOTE | Hostname ou adresse IP distante |
| PORT | Port distant + label service |
| LOCATION | Pays, ville du serveur |
| ORG | Organisation propriétaire de l'IP |
| TIME | Durée de la connexion |

## Licence

MIT — voir [LICENSE](LICENSE)

