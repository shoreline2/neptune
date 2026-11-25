# tyler-precision-tower

Neptune's Argo CD also deploys to `tyler-precision-tower`, the k3s cluster at home. The Applications are in `argocd/tyler-precision-tower/`, their manifests and values are in `k8s/tyler-precision-tower/`, and the `tyler-precision-tower` app of apps syncs them. Applications for the tower set `destination.name: tyler-precision-tower`.

Host-level configuration of the tower (Ansible, ZFS, backups) stays in the [tyler-precision-tower](https://github.com/shoreline2/tyler-precision-tower) repo.

## How neptune reaches the tower

No Kubernetes credentials are stored anywhere. The connection is authenticated by tailnet identity:

1. On the tower, the Tailscale operator runs an API server proxy at `tyler-precision-tower-k8s-operator`, in auth mode.
2. On neptune, the egress Service `argocd/tyler-precision-tower-k8s` sends Argo CD's requests through a proxy tagged `tag:argocd`.
3. A grant in the tailnet policy lets `tag:argocd` impersonate the group `argocd-neptune` on the tower.
4. On the tower, the ClusterRoleBinding `argocd-neptune` gives that group `cluster-admin`.

To cut neptune off from the tower, remove the grant.

## Setup

Neptune's Tailscale operator must already be set up (see `tailscale.md`).

1. In the Tailscale admin console, open **DNS** and check that MagicDNS and **HTTPS Certificates** are on. The API server proxy serves a Let's Encrypt certificate for its tailnet name.

2. In the access controls (policy file), add the tag owner and the grant.

   ```
   "tagOwners": {
     "tag:argocd": ["tag:k8s-operator"],
   },
   "grants": [
     {
       "src": ["tag:argocd"],
       "dst": ["tag:k8s-operator"],
       "ip":  ["tcp:443"],
       "app": {
         "tailscale.com/cap/kubernetes": [{"impersonate": {"groups": ["argocd-neptune"]}}],
       },
     },
   ],
   ```

3. Create the tower's operator Secret by copying neptune's. Both operators use the same OAuth client.

   ```
   kubectl --context tyler-precision-tower create namespace tailscale
   kubectl --context neptune get secret operator-oauth -n tailscale -o yaml \
     | grep -vE '^\s+(uid|resourceVersion|creationTimestamp):' \
     | kubectl --context tyler-precision-tower apply -f -
   ```

4. Install the operator and the RBAC on the tower by hand. Neptune can't reach the tower until both exist. Afterwards Argo CD takes them over.

   ```
   helm --kube-context tyler-precision-tower upgrade --install tailscale-operator tailscale-operator \
     --repo https://pkgs.tailscale.com/helmcharts --version 1.104.7 \
     -n tailscale -f k8s/tyler-precision-tower/tailscale-operator-values.yaml
   kubectl --context tyler-precision-tower apply -f k8s/tyler-precision-tower/rbac/
   ```

5. In Argo CD, sync `root-app`, then `tailscale-services`, then `tyler-precision-tower`, then `tower-tailscale-operator`.

6. Check the connection. In the Argo CD UI, **Settings > Clusters** should show `tyler-precision-tower` as `Successful`.

## Gotchas

- The operator on the tower is managed through the connection it provides. If a bad sync breaks it, neptune loses access, and step 4 is how to recover.
- `tower-tailscale-operator` keeps the Helm release name `tailscale-operator` from step 4, so Argo CD adopts the hand-installed resources rather than creating copies.
