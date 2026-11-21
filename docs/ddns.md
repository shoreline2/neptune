# DDNS

The cluster's public hostname is `neptune-mgmt.duckdns.org`, which is registered with DuckDNS. DuckDNS also resolves every subdomain to the same IP, so apps can use names such as `grafana.neptune-mgmt.duckdns.org` without any extra DNS records.

The record points at the public IP of the gateway's load balancer. Nothing updates the record automatically, so it must be changed by hand whenever that IP changes.

## When the IP changes

OKE creates the load balancer when Envoy Gateway creates the gateway's LoadBalancer Service. The IP stays the same for as long as the load balancer exists. A new IP is assigned if the `main-gateway` Gateway or the Envoy Gateway install is deleted and recreated, or if the cluster is rebuilt.

## Updating the record

1. Get the gateway's IP. The IP is in the `ADDRESS` column.

   ```
   kubectl get gateway main-gateway -n default
   ```

2. Sign in at https://www.duckdns.org and find `neptune-mgmt` in the domain list.

3. Replace the current IP with the IP from step 1 and click "update ip".

4. Check that the name resolves to the new IP. The change usually appears within a minute.

   ```
   nslookup neptune-mgmt.duckdns.org
   ```

## The DuckDNS token Secret

The DuckDNS webhook for cert-manager (see `docs/tls.md`) needs the DuckDNS account token. The token is stored in a Kubernetes Secret that is created by hand, so the token is never committed to git. The Secret must exist before the first certificate can be issued, for example after the cluster is rebuilt.

1. Copy the token from the top of the page at https://www.duckdns.org after signing in.

2. Create the namespace if it does not exist yet. An "already exists" error is safe to ignore.

   ```
   kubectl create namespace cert-manager
   ```

3. Create the Secret. Replace `<token>` with the token from step 1.

   ```
   kubectl create secret generic duckdns-token -n cert-manager --from-literal=token=<token>
   ```

## Rotating the token

DuckDNS can generate a new token from the account page. The old token stops working immediately, so the Secret must be replaced right away.

1. Delete the old Secret.

   ```
   kubectl delete secret duckdns-token -n cert-manager
   ```

2. Create the Secret again with the new token, as in step 3 of "The DuckDNS token Secret".

## Gotchas

- When a subdomain is created on duckdns.org, DuckDNS fills in the public IP of the browser that created it. That IP is not the gateway's IP, so the record must be updated before it will work.
- Terraform does not create the load balancer, so `terraform output` cannot show its IP. The kubectl command in step 1 of "Updating the record" is the way to look it up.
