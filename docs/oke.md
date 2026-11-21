# OKE nodes

The cluster is a Basic cluster, which is free. Basic clusters do not support automatic node cycling, so changes to the node pool's shape, image, or boot volume only apply to nodes created afterward. Existing nodes must be replaced by hand.

The A1 quota is fully used by the node, so a replacement cannot be created until the old node is gone. Replacing the node takes the whole cluster down for several minutes.

## Replacing a node

1. Get the node pool ID.

   ```
   cd iac
   terraform output -raw node_pool_id
   ```

2. List the nodes in the pool. Replace `<node-pool-id>` with the ID from step 1.

   ```
   oci ce node-pool get --node-pool-id <node-pool-id> --query 'data.nodes[].{id:id,name:name,state:"lifecycle-state"}' --output table
   ```

3. Delete the node. Replace `<node-pool-id>` and `<node-id>` with the IDs from steps 1 and 2. `--is-decrement-size false` keeps the pool size the same, so OKE creates a replacement with the current node pool settings.

   ```
   oci ce node-pool delete-node --node-pool-id <node-pool-id> --node-id <node-id> --is-decrement-size false
   ```

4. Watch for the new node to join and become `Ready`. This usually takes 5 to 10 minutes.

   ```
   kubectl get nodes --watch
   ```

## Gotchas

- Pods stay `Pending` until the new node is `Ready`. Argo CD, the certificate, and Secrets live in the control plane, so everything comes back without intervention.
- Block volumes reattach to the new node automatically, because it is in the same availability domain.
