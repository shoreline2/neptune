# Storage

Prometheus, Loki and Grafana share one 150 GB OCI block volume, each in its own subPath. The PVC (`observability-data-prometheus-prometheus-kube-prometheus-prometheus-0`) is created by the Prometheus StatefulSet; Loki and Grafana mount it by name.

## Reclaim policy

The `oci-bv` StorageClass creates volumes with the `Delete` reclaim policy, so deleting the PVC would also delete the volume and all the data. The PV is patched to `Retain` by hand. The patch is not in git, so it must be applied again whenever the PVC is recreated.

```
kubectl patch pv $(kubectl get pvc -n observability observability-data-prometheus-prometheus-kube-prometheus-prometheus-0 -o jsonpath='{.spec.volumeName}') -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

With `Retain`, deleting the PVC leaves the PV in the `Released` state and the volume stays in OCI, still counting against the 200 GB storage quota. Delete it in the OCI console once it is no longer needed.

## Backups

`iac/backups.tf` takes an incremental backup every day at 08:00 UTC and keeps each one for 4 days. The policy is attached to the volume by OCID (`observability_volume_id` in `iac/terraform.tfvars`). When the PVC is recreated, the volume gets a new OCID. Update the variable and run `terraform apply`. The variable's description has the command that finds the new OCID.

List the backups:

```
oci bv backup list --compartment-id <compartment-ocid> --volume-id <volume-ocid> --query 'data[].{name:"display-name",state:"lifecycle-state",created:"time-created"}' --output table
```

## Restoring from a backup

1. Create a volume from the backup in the node's availability domain. The new volume counts against the volume-count quota of 2, so the old volume may have to be deleted first.

   ```
   oci bv volume create --volume-backup-id <backup-ocid> --availability-domain <ad-name> --compartment-id <compartment-ocid> --display-name observability-restore
   ```

2. Stop the pods that use the volume (Prometheus, Loki, Grafana). The simplest way is to delete the `prometheus` and `loki` Argo CD apps without cascading, or to scale the workloads to zero.

3. Delete the old PVC, then create a PV for the restored volume. Set `csi.volumeHandle` to the new volume's OCID, `storageClassName: oci-bv`, `persistentVolumeReclaimPolicy: Retain`, and a `claimRef` that points to `observability/observability-data-prometheus-prometheus-kube-prometheus-prometheus-0`. The PVC is then recreated by the StatefulSet and binds to this PV.

4. Sync the apps, and update `observability_volume_id` so the new volume is backed up.
