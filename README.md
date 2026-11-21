# neptune

Neptune is the name of the cluster run in Oracle Cloud Infrastructure (OCI).

## Connecting kubectl

The OCI CLI must be installed and configured in `~/.oci/config`. kubectl uses the OCI CLI to authenticate on each call, so there are no static tokens to manage.

1. Get the cluster ID.

   ```sh
   cd iac
   terraform output -raw cluster_id
   ```

2. Add the cluster to `~/.kube/config`. Replace `<cluster-id>` with the ID from step 1. Type everything else exactly as shown. `PUBLIC_ENDPOINT` is a fixed option that tells kubectl to connect through the cluster's public IP, so it is not a value to look up.

   ```sh
   oci ce cluster create-kubeconfig \
     --cluster-id <cluster-id> \
     --file ~/.kube/config \
     --region us-ashburn-1 \
     --token-version 2.0.0 \
     --kube-endpoint PUBLIC_ENDPOINT
   ```

   The command merges the cluster into the existing kubeconfig and makes it the current context. When it succeeds, it prints `Existing Kubeconfig file found at ... and new config merged into it`.

3. Check that kubectl can reach the cluster.

   ```sh
   kubectl config current-context
   kubectl get nodes
   ```

   The first command prints a context name such as `context-neptune-oke-cluster-c7sofe3py6a`. The second command should list two nodes.

4. Optionally, rename the context to something stable, because the generated name changes whenever the cluster is rebuilt. Use the context name that step 3 printed.

   ```sh
   kubectl config rename-context <context-name> neptune
   ```

### Gotchas

- The Kubernetes API only accepts connections from the IP ranges listed in `admin_cidrs` in `iac/terraform.tfvars`. If kubectl times out, the local public IP has probably changed. Update `admin_cidrs` and run `terraform apply`.
- A rebuilt cluster gets a new ID, so steps 1 through 3 must be repeated. The old `context-neptune-oke-cluster-*` entry can be removed with `kubectl config delete-context <name>`.
