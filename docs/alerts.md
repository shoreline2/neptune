# Alerts

Alertmanager sends alerts to a topic on the public ntfy.sh server, and the ntfy app on the phone is subscribed to that topic. Alertmanager has no ntfy receiver of its own, so it uses a generic webhook. The `?template=alertmanager` query parameter tells ntfy to turn the webhook payload into a readable notification.

Anyone who knows the topic name can read and publish to it, so the name is random and kept out of git. The full URL is stored in a Kubernetes Secret that is created by hand. The Secret is mounted into Alertmanager at `/etc/alertmanager/secrets/alertmanager-ntfy/url`.

Routing is set in `k8s/observability/values.yaml` under `alertmanager.config`. The always-firing `Watchdog` and `InfoInhibitor` alerts, `severity=info` alerts, and CPU throttling of the OKE-managed kube-system pods go nowhere. Everything else goes to ntfy, including a second message when the alert resolves.

## The ntfy Secret

The Secret must exist before the `prometheus` app is synced, for example after the cluster is rebuilt. Without it, the Alertmanager pod can't start.

1. Choose a topic name. The following command generates a random one.

   ```
   echo "neptune-alerts-$(openssl rand -hex 12)"
   ```

2. Create the Secret. Replace `<topic>` with the name from step 1.

   ```
   kubectl create secret generic alertmanager-ntfy -n observability --from-literal=url='https://ntfy.sh/<topic>?template=alertmanager'
   ```

3. In the ntfy app, subscribe to the topic on the default server (ntfy.sh).

## Finding the current topic

```
kubectl get secret alertmanager-ntfy -n observability -o jsonpath='{.data.url}' | base64 -d
```

## Sending a test alert

This posts a fake alert straight to Alertmanager. It shows up on the phone within about 30 seconds and resolves after 5 minutes.

```
kubectl port-forward -n observability svc/prometheus-kube-prometheus-alertmanager 9093 &
curl -X POST localhost:9093/api/v2/alerts -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"TestAlert","severity":"warning"},"annotations":{"summary":"Test from neptune"},"endsAt":"'$(date -u -d '+5 min' +%Y-%m-%dT%H:%M:%SZ)'"}]'
```
