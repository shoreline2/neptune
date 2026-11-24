# Manual Argo CD install

These steps assume kubectl is connected to the cluster (see the README).

1. Create the namespace.

   ```
   kubectl create namespace argocd
   ```

2. Install Argo CD. The version is pinned so that a rebuild installs the same release. Server-side apply is required because the Argo CD CRDs are too large for a regular apply.

   ```
   kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.6.2/manifests/install.yaml
   ```

3. Wait until every pod in the namespace shows `Running`.

   ```
   kubectl get pods -n argocd
   ```

4. Apply the root app. Argo CD then deploys everything under `argocd/apps` from the `main` branch on GitHub.

   ```
   kubectl apply -f argocd/root-app.yaml
   ```

5. Print the initial admin password. The output is base64 encoded.

   ```
   kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}'
   ```

6. Decode the password from step 5.

   ```
   echo <encoded-password> | base64 -d
   ```

7. Allow anonymous access with full admin rights. The UI is only reachable over the tailnet, which has a single user, so no login is needed. The `admin` login from steps 5-6 still works for the CLI.

   ```
   kubectl patch cm argocd-cm -n argocd --type merge -p '{"data":{"users.anonymous.enabled":"true"}}'
   kubectl patch cm argocd-rbac-cm -n argocd --type merge -p '{"data":{"policy.default":"role:admin"}}'
   ```

8. Open the UI at https://neptune-argocd. Argo CD uses a self-signed certificate, so the browser shows a warning. The tailnet Service is in `k8s/tailscale/services.yaml` and needs the Tailscale operator to be synced first. Before that, use a port forward instead. While this command runs, the UI is at https://localhost:8080.

   ```
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
