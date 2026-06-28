# ArgoCD

## Install

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Get admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

## Port-forward

```bash
kubectl -n argocd port-forward svc/argocd-server 8000:80
```

## Install CLI

```bash
# Linux / WSL
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Windows (PowerShell)
# winget install ArgoCD.ArgoCD
```

## Login

```bash
argocd login localhost:8000 --username admin --insecure
```

## Verify

```bash
kubectl get pods -n argocd
kubectl get application -n argocd
```

---

# Bootstrap (App of Apps)

Deploy sequence — apply in this order.

## 1. AppProjects

Cria os 3 projetos (infrastructure, platform, workloads) a partir dos manifests renderizados em `apps/appprojects/rendered/`.

```bash
kubectl apply -f apps/bootstrap/appprojects.yaml
```

## 2. Dev environment

Cria o ApplicationSet `appset-dev` que gera a Application `seaweedfs-dev`.

```bash
kubectl apply -f apps/bootstrap/dev.yaml
```

## 3. Stage / Prod

```bash
kubectl apply -f apps/bootstrap/stage.yaml
kubectl apply -f apps/bootstrap/prod.yaml
```

## Monitorar

```bash
kubectl get application -n argocd -w
argocd app list
```
