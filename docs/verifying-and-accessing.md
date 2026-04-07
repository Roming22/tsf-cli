# Verifying and accessing Trusted Software Factory

After the deployment completes, verify that all TSF components are running correctly and access the service UIs. If you encounter issues, use the [troubleshooting](#troubleshooting) section to diagnose and resolve common installation problems.

## Accessing the Konflux UI

Access the Konflux web interface to verify that the deployment succeeded and to begin onboarding applications to TSF.

### Prerequisites

- The TSF deployment has completed.
- You have the Konflux UI URL from the deployment output.

### Steps

1. Open the Konflux UI URL in a web browser.

   If you did not save the URL from the deployment output, find it through the OCP Routes:

   ```bash
   oc get routes -n konflux-ui
   ```

   Open the URL in the `HOST/PORT` column.

2. On the OCP login page, enter your cluster administrator credentials and click **Log in**.

3. On the **Authorize Access** page, the `dex-client` service account in the `konflux-ui` project requests permission to access your account. Review the requested permission:
   - `user:info` — read-only access to your user information, including username, identities, and group membership.

4. Click **Allow selected permissions**.

### Verification

The Konflux dashboard loads and displays the **Get started with Konflux** landing page with options to view namespaces and access the Release Monitor Board.

## Verifying the deployment

Verify that all TSF operators, secrets, and routes are running correctly on your OCP cluster. Use this procedure to confirm a successful installation or to diagnose which components need attention.

### Steps

1. Verify that all TSF operators are installed and available:

   ```bash
   oc get csv -A | grep -E "(konflux|pipelines|cert-manager|rhbk|rhtpa)"
   ```

   Each operator should show a phase of `Succeeded`.

2. Verify that the integration secrets were created in the `tsf` namespace:

   ```bash
   oc get secrets -n tsf
   ```

   The output should include `tsf-github-integration` (or a GitLab secret) and `tsf-quay-integration`.

3. Verify that the service routes are available:

   ```bash
   oc get routes -A | grep -E "(konflux|tsf-tas|tsf-tpa)"
   ```

   The output should show routes for the Konflux UI, Red Hat Trusted Artifact Signer services (Fulcio, Rekor, TUF), and Red Hat Trusted Profile Analyzer.

4. Verify that all pods are running without errors:

   ```bash
   oc get pods -n tsf --field-selector=status.phase!=Running
   ```

   If the command returns no results, all pods in the `tsf` namespace are running.

## Deployed components

The TSF installer deploys the following components to your OCP cluster. Each component runs in its own namespace and is managed by a Helm chart.

| Component | Namespace | Helm chart | Description |
|-----------|-----------|------------|-------------|
| Red Hat Cert-Manager Operator | `cert-manager-operator` | `tsf-cert-manager` | Manages application certificate lifecycle. |
| Red Hat build of Keycloak | `tssc-keycloak` | `tsf-infrastructure` | Provides identity management and single sign-on. |
| Konflux Operator | `konflux-operator` | `tsf-subscriptions` | Provides the custom resource definitions for the build system. |
| Konflux UI | `konflux-ui` | `tsf-konflux` | Provides the web interface for managing applications and builds. |
| Red Hat OpenShift Pipelines | Managed subscription | `tsf-subscriptions` | Provides Tekton-based CI/CD pipelines. |
| Red Hat Trusted Artifact Signer | `tsf-tas` | `tsf-tas` | Provides cryptographic signing and verification of software artifacts using Fulcio, Rekor, and TUF services. |
| Red Hat Trusted Profile Analyzer | `tsf-tpa` | `tsf-infrastructure` | Analyzes software bills of materials (SBOMs) and vulnerability data. |
| Quay integration | `tssc-quay` | Integration configuration | Stores credentials for pushing container images to Quay.io. |

The installer also creates the following supporting namespaces:

- `openshift-storage`
- `rhbk-operator`
- `rhtpa-operator`

The `tsf-config` ConfigMap in the `tsf` namespace controls which components are installed. Each component has an `enabled` flag and a `manageSubscription` property. Set `manageSubscription` to `false` for any component that is already installed on the cluster.

To view the complete ConfigMap structure:

```bash
oc get configmap tsf-config -n tsf -o yaml
```

## Troubleshooting

### Quay token error during deployment

**Symptom:** The `tsf deploy` command fails at the `tsf-konflux` chart with:

```
Error: install failed: execution error at (tsf-konflux/templates/quaytoken-secret.yaml:3:19): token field not found in secret
```

**Cause:** The Quay OAuth token is expired, invalid, or was not saved correctly during the integration step.

**Resolution:**

1. Regenerate the Quay OAuth token in your Quay.io organization.
2. Delete the existing Quay secret:

   ```bash
   oc delete secret tsf-quay-integration -n tsf
   ```

3. Re-run the Quay integration:

   ```bash
   tsf integration quay \
     --organization="$QUAY__ORG" \
     --token="$QUAY__API_TOKEN" \
     --url="$QUAY__URL"
   ```

4. Re-run the deployment:

   ```bash
   tsf deploy
   ```

### Cert-Manager subscription conflict

**Symptom:** The deployment fails with a subscription conflict error for the Cert-Manager operator.

**Cause:** The Red Hat Cert-Manager Operator is already installed on the cluster. The TSF installer attempts to create a second subscription, which conflicts with the existing one.

**Resolution:** Edit the `tsf-config` ConfigMap and set `manageSubscription` to `false` for the Cert-Manager component:

```bash
oc edit configmap tsf-config -n tsf
```

Locate the Cert-Manager entry and change `manageSubscription: true` to `manageSubscription: false`. Then re-run the deployment.

### Red Hat Trusted Profile Analyzer UI URL is not accessible

**Symptom:** The RHTPA UI URL displayed in the deployment output shows `server%s(<nil>)` or returns an error.

**Cause:** The RHTPA service may not have started correctly, or the PostgreSQL database that it depends on is not running.

**Resolution:**

1. Check the RHTPA operator pod status:

   ```bash
   oc get pods -n tsf-tpa
   ```

2. Check the PostgreSQL pod status:

   ```bash
   oc get pods -n tsf-tpa | grep postgres
   ```

3. If pods are in error state, check the logs:

   ```bash
   oc logs -n tsf-tpa deployment/rhtpa-operator
   ```

4. As a workaround, find the correct route URL directly:

   ```bash
   oc get routes -n tsf-tpa
   ```

### Deployment appears to hang

**Symptom:** The `tsf deploy` command runs for an extended period without producing any output.

**Cause:** Some Helm charts take several minutes to deploy, especially when pulling container images for the first time. The installer does not display a progress indicator during these periods.

**Resolution:** The deployment is likely still running. In a separate terminal, monitor the pod status:

```bash
oc get pods -A --watch
```

Wait for the deployment to complete. The full process typically takes 30 to 60 minutes.

### Browser fails to open during GitHub integration

**Symptom:** The `tsf integration github --create` command logs an error:

```
level=ERROR msg="failed to open browser" error="exec: \"xdg-open\": executable file not found in $PATH"
```

**Cause:** The installer container does not have a graphical browser or the `xdg-open` utility. The command attempts to open the URL automatically but cannot do so inside the container.

**Resolution:** Copy the `localhost:8228` URL from the command output and open it manually in a web browser on your local machine.

## Next step

Proceed to [Getting started with Trusted Software Factory](getting-started.md) to onboard your first application.
