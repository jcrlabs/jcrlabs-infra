# Runbook — jcrlabs Infrastructure

## Acceso al cluster

```bash
# Copiar kubeconfig desde master
ssh ubuntu@192.168.1.10 cat ~/.kube/config > ~/.kube/jcrlabs-config
export KUBECONFIG=~/.kube/jcrlabs-config
kubectl get nodes
```

## ArgoCD

### Obtener password inicial
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Forzar sync de una app
```bash
argocd app sync <app-name>
# o vía kubectl
kubectl -n argocd patch application <app-name> \
  -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {}}}' \
  --type merge
```

### Ver estado de todas las apps
```bash
argocd app list
```

## Añadir nuevo proyecto (ver new-project-checklist.md)

## cert-manager

### Ver estado de certificados
```bash
kubectl get certificates -A
kubectl get certificaterequests -A
kubectl get orders -A  # ACME orders
```

### Forzar renovación de certificado
```bash
kubectl -n cert-manager annotate certificate wildcard-jcrlabs-net \
  cert-manager.io/issuer-name=letsencrypt-prod
cmctl renew wildcard-jcrlabs-net -n cert-manager
```

## MetalLB

### Ver IPs asignadas
```bash
kubectl get services -A --field-selector spec.type=LoadBalancer
```

### Ver pool de IPs
```bash
kubectl get ipaddresspools -n metallb-system
```

## Sealed Secrets

### Generar nuevo sealed secret
```bash
# Obtener cert público
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets > /tmp/pub-cert.pem

# Cifrar secret
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=YOUR_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal --cert /tmp/pub-cert.pem \
  --format yaml > k8s/sealed-secrets/cloudflare-api-token.yaml
```

## Nextcloud NAS (nas.jcrlabs.net)

Nextcloud vive en el namespace `nextcloud`. BD PostgreSQL y Redis como subcharts
(en SSD, `local-path`). Los datos de usuario van en una carpeta del disco del
sistema (`/` = sdb2, ~575 GB libres), expuesta como PV `local` estático
(`nextcloud-data-pv`, path `/var/lib/nextcloud-data`, reclaimPolicy `Retain`).

> **No se formatea ni se particiona nada.** El disco `sda2` (LUKS cifrado) queda
> intacto. Solo se crea un directorio dentro del filesystem raíz existente.

### Preparar el directorio de datos (una sola vez, en el host)

```bash
sudo mkdir -p /var/lib/nextcloud-data
sudo chown -R 33:33 /var/lib/nextcloud-data   # uid/gid www-data del contenedor
```

### Secretos

Tres SealedSecrets en `k8s/sealed-secrets/nextcloud-secrets.yaml`:
`nextcloud-admin` (usuario/password admin), `nextcloud-db` (postgres-password +
password del usuario `nextcloud`) y `nextcloud-redis` (redis-password). Se sellan
con `kubeseal` como el resto (ver sección Sealed Secrets). La contraseña de admin
se guarda en el gestor de contraseñas del equipo.

### Operación

```bash
kubectl -n nextcloud get pods,pvc,ingress
kubectl -n nextcloud exec deploy/nextcloud -c nextcloud -- \
  php occ status                            # estado de la instancia
kubectl -n nextcloud exec deploy/nextcloud -c nextcloud -- \
  php occ maintenance:mode --on             # antes de tareas de mantenimiento
```

> Cloudflare (plan free) limita cada request proxied a ~100 MB. Nextcloud sube en
> chunks por defecto (web y cliente de escritorio), así que ficheros grandes
> funcionan igual a través del túnel.

## Monitoring

### Ver alertas activas
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093
# Abrir http://localhost:9093
```

### Reiniciar Prometheus si OOM
```bash
kubectl -n monitoring rollout restart statefulset/prometheus-kube-prometheus-stack-prometheus
```

### Ver logs de un pod vía Loki (Grafana)
Ir a Grafana → Explore → Loki → `{namespace="inventory", pod=~".*"}`

## Disaster Recovery

### Re-bootstrap completo desde cero
```bash
cd ansible/
ansible-playbook -i inventory/homelab.yml playbooks/00-base.yml
ansible-playbook -i inventory/homelab.yml playbooks/01-containerd.yml
ansible-playbook -i inventory/homelab.yml playbooks/02-kubeadm-init.yml
ansible-playbook -i inventory/homelab.yml playbooks/03-kubeadm-join.yml
ansible-playbook -i inventory/homelab.yml playbooks/04-cni.yml
ansible-playbook -i inventory/homelab.yml playbooks/05-bootstrap.yml
```

Después de bootstrap, ArgoCD reconcilia todo el estado desde Git automáticamente.

## Troubleshooting

### Pod en CrashLoopBackOff
```bash
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --previous
```

### Node NotReady
```bash
kubectl describe node <node>
journalctl -u kubelet -f  # en el nodo
```

### ArgoCD app OutOfSync tras cambio
```bash
argocd app diff <app-name>  # ver qué cambia
argocd app sync <app-name>  # aplicar
```
