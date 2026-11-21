# TLS

HTTPS uses a free Let's Encrypt certificate that cert-manager issues and renews automatically. The certificate covers `neptune-mgmt.duckdns.org` and `*.neptune-mgmt.duckdns.org`, and the Gateway terminates TLS with it. Plain HTTP requests are redirected to HTTPS.

Let's Encrypt verifies the two names in different ways. The wildcard name is verified with a DNS TXT record, which the DuckDNS webhook creates through the DuckDNS API. The apex name is verified over HTTP through the Gateway, because DuckDNS can only hold one TXT record at a time.

The DuckDNS webhook reads the DuckDNS token from a Secret that is created by hand. The steps to create and rotate it are in `docs/ddns.md`.

## Switching between staging and production

Let's Encrypt has a staging server with untrusted certificates and generous rate limits. It is meant for testing. The certificate's issuer is set in `k8s/gateway/certificate.yaml`.

1. Change `issuerRef.name` to `letsencrypt-prod` (or back to `letsencrypt-staging`) and merge the change into `main`.

2. After Argo CD syncs, cert-manager issues a new certificate from the new issuer. Check its progress. `READY` becomes `True` when the certificate is issued.

   ```
   kubectl get certificate neptune-mgmt -n default
   ```

## Gotchas

- Browsers show a security warning for staging certificates. That is expected, because the staging server's root certificate is not trusted.
- If `READY` stays `False`, the reason is usually in the related challenge. The `kubectl describe challenges -n default` command shows which name failed and why.
