# Verifying and accessing Trusted Software Factory

After the deployment completes, access the service UIs and verify that all TSF components are running correctly. If you encounter issues, see [Troubleshooting TSF installation](troubleshooting.md).

## Accessing the Konflux UI

Access the Konflux web interface to verify that the deployment succeeded and to begin onboarding applications to TSF.

### Prerequisites

- You have completed the TSF deployment.
- You have the Konflux UI URL from the deployment output.

### Steps

1. Open the Konflux UI URL in a web browser.

   If you did not save the URL from the deployment output, find it through the OCP Routes:

   ```bash
   oc get routes -n konflux-ui
   ```

   Open the URL in the `HOST/PORT` column.

2. On the OCP login page, enter your credentials and click **Log in**.

3. On the **Authorize Access** page, the `dex-client` service account in the `konflux-ui` project requests permission to access your account. Review the requested permission:
   - `user:info` — read-only access to your user information, including username, identities, and group membership.

4. Click **Allow selected permissions**.

### Verification

The Konflux dashboard loads and displays the **Get started with Konflux** landing page with options to view namespaces and access the Release Monitor Board.

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

## Next step

Proceed to [Getting started with Trusted Software Factory](getting-started.md) to onboard your first application.
