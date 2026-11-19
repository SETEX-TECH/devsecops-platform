# Plateforme DevSecOps sur VM Ubuntu Server (Proxmox)

Même pipeline que la version AWS, mais tout tourne dans une VM : k3s à la place d'EKS,
registre Docker local à la place d'ECR, runner GitHub auto-hébergé à la place des runners GitHub.
Coût : 0. Aucune adresse IP publique nécessaire (le runner et ArgoCD sortent vers GitHub).

## 1. Préparer la VM dans Proxmox

- Ubuntu Server 22.04 ou 24.04 LTS (ISO dans Proxmox > local > ISO Images).
- 4 cœurs (type `host`), 8 Go de RAM minimum (12 à 16 Go confortable), disque 80 Go (VirtIO SCSI).
- Désactivez le « Ballooning » (Memory > Advanced). Options > QEMU Guest Agent : activé.
- Réseau en mode bridge (vmbr0) pour joindre la VM depuis votre PC.
- À l'installation d'Ubuntu : cochez « Install OpenSSH server ».
- **Faites un snapshot Proxmox avant chaque phase** (VM > Snapshots) : vous pourrez revenir en arrière.

## 2. Récupérer le kit et vérifier les ressources

```bash
sudo apt-get update && sudo apt-get install -y git unzip
# copiez l'archive dans la VM (scp), puis :
unzip devsecops-vm-kit.zip && cd devsecops-vm-kit
chmod +x scripts/*.sh
./scripts/00-check-resources.sh
```

## 3. Installer l'environnement (dans l'ordre)

```bash
./scripts/01-install-base.sh        # Docker, Trivy, Helm, Python
# déconnectez-vous puis reconnectez-vous (groupe docker)
./scripts/02-install-k3s.sh         # Kubernetes
./scripts/03-install-registry.sh    # registre localhost:5000
./scripts/04-install-platform.sh    # ArgoCD, Kyverno, Prometheus, Grafana
```

Avec plus de RAM : `INSTALL_LOKI=true INSTALL_FALCO=true ./scripts/04-install-platform.sh`.
Le script affiche les mots de passe admin d'ArgoCD et de Grafana : notez-les.

## 4. Créer le dépôt GitHub

1. Créez un dépôt (privé ou public), poussez le contenu du kit sur `main`, puis créez la branche `develop`.
2. Remplacez dans `argocd/*.yaml` : `<ORGANISATION>` et `<DEPOT>` (si le dépôt est privé, ajoutez-le dans ArgoCD avec un jeton : Settings > Repositories).
3. Protégez `main` et `develop` (revue et checks obligatoires).
4. Créez l'environnement `production` avec « Required reviewers » (Settings > Environments).

## 5. Installer le runner GitHub

Dans GitHub : dépôt > Settings > Actions > Runners > New self-hosted runner (Linux x64), copiez le jeton.

```bash
REPO_URL=https://github.com/<ORGANISATION>/<DEPOT> RUNNER_TOKEN=<JETON> ./scripts/05-install-runner.sh
```

Le runner doit apparaître « Idle ». (Si votre VM est en ARM, utilisez l'archive `linux-arm64`.)

## 6. Déployer

```bash
kubectl apply -f argocd/
```

- Poussez sur `develop` : build, scans, push vers `localhost:5000`, mise à jour GitOps, ArgoCD déploie en dev.
- Fusionnez dans `main` : staging, test DAST (ZAP), puis promotion en production après votre validation.
- Les applications ArgoCD affichent « ImagePullBackOff » tant que le premier pipeline n'a pas poussé d'image : c'est normal.

## 7. Accès depuis votre PC (remplacez IP_VM)

| Service | Adresse |
|---|---|
| Application dev | http://IP_VM:30080 |
| Application staging | http://IP_VM:30081 |
| Application production | http://IP_VM:30082 |
| ArgoCD | http://IP_VM:30090 (admin) |
| Grafana | http://IP_VM:30030 (admin) |
| Prometheus | http://IP_VM:30091 |

## 8. Vérifier que la sécurité bloque bien

- **Secret** : ajoutez un fichier avec une fausse clé AWS (`AKIAIOSFODNN7EXAMPLE` n'est pas toujours détectée : utilisez une clé factice au bon format) et poussez : Gitleaks doit échouer.
- **Dépendance vulnérable** : mettez une très vieille version dans `app/requirements.txt` : Trivy doit échouer.
- **Pod non conforme** : `kubectl run test --image=nginx:latest -n app-dev` doit être refusé par Kyverno.
- **Rollback** : `git revert` du dernier commit de déploiement, ArgoCD revient à la version précédente.

## 9. Dépannage rapide

| Problème | Piste |
|---|---|
| `permission denied` sur Docker | reconnectez-vous, ou `newgrp docker` |
| Pod en `ImagePullBackOff` | `curl localhost:5000/v2/_catalog` doit lister l'image ; sinon relancez le pipeline |
| Runner « Offline » | `sudo systemctl status actions.runner.*` |
| Manque de mémoire | `free -h` ; désactivez Loki/Falco, ou augmentez la RAM dans Proxmox |
| Disque plein | `docker system prune -af` ; agrandissez le disque dans Proxmox |

## 10. Plan de travail (12 semaines, adapté VM)

1. Semaines 1-2 : VM, scripts 00 à 03, dépôt GitHub, application d'exemple.
2. Semaines 3-4 : runner et CI avec scans de sécurité, tests de blocage.
3. Semaines 5-6 : ArgoCD, Kyverno, déploiement dev/staging/prod.
4. Semaines 7-8 : DAST, Grafana, alertes, éventuellement Loki et Falco.
5. Semaines 9-11 : API FastAPI, score de risque, détection d'anomalies, assistant LLM.
6. Semaine 12 : interface React, démonstrations, rapport.

## Limites de cette version

- La signature d'images (Cosign) est retirée : elle suppose l'identité GitHub OIDC. Elle peut être réintroduite avec une paire de clés.
- Checkov est en mode `--soft-fail` au départ ; retirez-le une fois les constats traités.
- Mono-nœud : pas de haute disponibilité (suffisant pour un projet académique).
- Le registre est en HTTP sur localhost : acceptable en laboratoire, pas en production.
