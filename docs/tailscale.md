# Tailscale

The Tailscale Kubernetes operator puts selected Services on the tailnet. Nothing it exposes is reachable from the internet.

| Tailnet name | Service | Used for |
|---|---|---|
| `neptune-prometheus` | Prometheus, port 9090 | Home devices remote-write metrics to `/api/v1/write` |
| `neptune-loki` | Loki, port 3100 | Home devices push logs to `/loki/api/v1/push` |
| `neptune-grafana` | Grafana, port 80 | Grafana UI |
| `neptune-argocd` | Argo CD, port 443 | Argo CD UI |

One Service goes the other way. The egress Service `argocd/tyler-precision-tower-k8s` lets Argo CD reach the tower's API server proxy (see `tyler-precision-tower.md`).

The operator authenticates with an OAuth client. Its credentials are stored in a Secret that is created by hand, so they are never committed to git.

## Setup

1. In the Tailscale admin console, open the access controls (policy file) and add these tag owners. The operator tags itself `tag:k8s-operator` and tags each proxy `tag:k8s`.

   ```
   "tagOwners": {
     "tag:k8s-operator": [],
     "tag:k8s": ["tag:k8s-operator"],
   }
   ```

2. Create an OAuth client in the admin console settings. Give it write access to the Devices Core, Auth Keys, and Services scopes, and add the tag `tag:k8s-operator`. Copy the client ID and secret.

3. Create the namespace. An "already exists" error is safe to ignore.

   ```
   kubectl create namespace tailscale
   ```

4. Create the Secret. Replace `<client-id>` and `<client-secret>` with the values from step 2.

   ```
   kubectl create secret generic operator-oauth -n tailscale --from-literal=client_id=<client-id> --from-literal=client_secret=<client-secret>
   ```

5. In Argo CD, sync `root-app`, then `tailscale-operator`, then `tailscale-services`.

6. Check that the operator and the four proxies joined the tailnet. They appear in the admin console as `neptune-k8s-operator`, `neptune-prometheus`, `neptune-loki`, `neptune-grafana`, and `neptune-argocd`.

## Gotchas

- If the default policy allows all traffic, every device on the tailnet can reach these Services. To restrict that, add grants that allow only the home devices to reach `tag:k8s` on ports 9090 and 3100.
- Prometheus's remote write endpoint and Loki's push endpoint have no authentication of their own. The tailnet is the access control.
