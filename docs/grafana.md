# Grafana

Grafana is installed by the kube-prometheus-stack chart in the `observability` namespace.

## The admin Secret

The Grafana admin username and password are stored in a Kubernetes Secret that is created by hand, so the password is never committed to git. The chart reads the Secret through `grafana.admin.existingSecret`. Without it, the chart generates a new random password on every render, which keeps the Argo CD app OutOfSync and changes the password on every sync.

The Secret must exist before Grafana is synced, for example after the cluster is rebuilt.

1. Choose a strong password. The following command generates a random one.

   ```
   openssl rand -base64 24
   ```

2. Create the namespace if it does not exist yet. An "already exists" error is safe to ignore.

   ```
   kubectl create namespace observability
   ```

3. Create the Secret. Replace `<password>` with the password from step 1. The key names `admin-user` and `admin-password` are the ones the chart expects.

   ```
   kubectl create secret generic grafana-admin -n observability --from-literal=admin-user=admin --from-literal=admin-password=<password>
   ```

4. Check that the Secret exists and has both keys.

   ```
   kubectl describe secret grafana-admin -n observability
   ```

## Changing the password

Grafana stores the admin password in its own database after the first start, so updating the Secret alone does not change the password of a running Grafana. The password must also be reset inside Grafana.

1. Delete the old Secret.

   ```
   kubectl delete secret grafana-admin -n observability
   ```

2. Create the Secret again with the new password, as in step 3 of "The admin Secret".

3. Reset the password inside the running Grafana. Replace `<password>` with the new password.

   ```
   kubectl exec -n observability deploy/prometheus-grafana -c grafana -- grafana cli admin reset-admin-password <password>
   ```
