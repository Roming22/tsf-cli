# Installing Trusted Software Factory

Install Trusted Software Factory (TSF) by starting the installer container, configuring the cluster and integrations, and deploying all services. This phase assumes you have [prepared your environment and credentials](preparing-to-install.md).

## Start the installer container

Start the TSF installer container using Podman. The installer runs in a container image that includes the `tsf` command-line tool and all required dependencies.

### Prerequisites

- You have prepared the `tsf.env` file with your cluster and integration credentials.
- You have Podman installed on your local system.

### Steps

1. Navigate to the directory that contains your `tsf.env` file.

2. Start the TSF installer container:

   ```bash
   podman run -it --rm --env-file tsf.env \
     --entrypoint bash -p 8228:8228 --pull always \
     quay.io/redhat-ads/tsf-cli:unstable --login
   ```

   This command pulls the latest installer image and opens an interactive shell session inside the container. The `--login` flag sources the shell profile, and port 8228 is exposed for the GitHub App creation workflow.

3. In the container terminal, log in to your OCP cluster:

   ```bash
   oc login "$OCP__API_ENDPOINT" \
     --username "$OCP__USERNAME" \
     --password "$OCP__PASSWORD"
   ```

   If the cluster uses a self-signed certificate, type `y` when prompted to use an insecure connection.

### Verification

Verify that you are logged in with `cluster-admin` privileges:

```bash
oc whoami
```

The output should show the username you specified in your environment file.

## Configure the cluster

Create the TSF configuration on your OCP cluster. This step creates a ConfigMap that defines which components TSF installs and how they are configured.

### Steps

1. Create the TSF configuration:

   ```bash
   tsf config --create
   ```

   This command creates a `tsf-config` ConfigMap in the `tsf` namespace. The ConfigMap contains a `config.yaml` key that lists all components with their namespaces and `manageSubscription` settings.

2. Check if the Red Hat Cert-Manager Operator is already installed on the cluster:

   ```bash
   oc get subscription openshift-cert-manager-operator -n cert-manager-operator
   ```

   - If the command returns a subscription, Cert-Manager is already installed. Continue to step 3.
   - If the command returns `NotFound`, Cert-Manager is not installed. Skip to the verification step.

3. Edit the `tsf-config` ConfigMap to disable the Cert-Manager managed subscription:

   ```bash
   oc edit configmap tsf-config -n tsf
   ```

   Locate the Cert-Manager product entry and set `manageSubscription` to `false`:

   ```yaml
   products:
     - name: Cert-Manager
       enabled: true
       properties:
         manageSubscription: false
   ```

> **Note:** The TSF installer assumes a fresh cluster. If other TSF-managed operators are already installed (such as Red Hat OpenShift Pipelines or Red Hat Trusted Artifact Signer), set `manageSubscription: false` for each pre-installed component to prevent conflicts.

### Verification

Verify that the ConfigMap was created:

```bash
oc get configmap tsf-config -n tsf
```

The output should show the `tsf-config` ConfigMap in the `tsf` namespace.

## Configure the GitHub integration

Create and install a GitHub App that enables TSF to interact with your GitHub repositories. The GitHub App provides webhooks for triggering builds and access to repository contents.

### Prerequisites

- You have started the TSF installer container.
- You are logged in to the OCP cluster.
- You have created the TSF configuration on the cluster.
- You have a GitHub organization.

### Steps

1. Create the GitHub App:

   ```bash
   tsf integration github --create --org "$GITHUB__ORG" "<my_github_app_name>"
   ```

   The command outputs a URL starting with `http://localhost:8228`.

   > **Note:** The installer may log an error about failing to open the browser. This is expected when running inside a container. Copy the `localhost:8228` URL from the output and open it manually in your web browser.

2. Open the URL in a web browser. The page displays a **Create your GitHub App** button.

3. Click **Create your GitHub App**. You are redirected to GitHub to configure the app.

4. On the GitHub App creation page, review the pre-filled settings and click **Create GitHub App**.

5. After the app is created, click **Install the GitHub App** to install it on your organization.

6. Select your GitHub organization from the list.

7. Review the permissions that the app requests:
   - Read access to members, metadata, and organization plan
   - Read and write access to administration, checks, code, issues, pull requests, and workflows

8. Click **Install**.

### Verification

- The GitHub App page displays with a **Website** link that points to the Konflux UI. You can use this link to access the UI after deployment is complete.
- In the GitHub organization settings under **Developer settings > GitHub Apps**, the newly created app appears with the correct permissions.

## Configure the GitLab integration

If you are using GitLab instead of GitHub, configure the GitLab integration. Create a Project Access Token for each GitLab project that you want to onboard to TSF.

### Prerequisites

- You have started the TSF installer container.
- You are logged in to the OCP cluster.
- You have a GitLab project that you want to onboard.

### Steps

1. In your GitLab project, create a Project Access Token:
   1. Navigate to **Settings** > **Access Tokens**.
   2. Enter a name for the token, for example, `tsf-integration`.
   3. Select the **Maintainer** role.
   4. Select the following scopes: `api`, `read_repository`, `write_repository`.
   5. Click **Create project access token**.
   6. Copy the token value.

2. Create a Kubernetes secret in the tenant namespace that contains the GitLab credentials:

   ```bash
   oc create secret generic gitlab-auth-secret \
     -n <tenant-namespace> \
     --from-literal=password=<project-access-token> \
     --type=kubernetes.io/basic-auth
   ```

   Replace `<tenant-namespace>` with your tenant namespace and `<project-access-token>` with the token you copied.

3. Label the secret so that Konflux can discover it:

   ```bash
   oc label secret gitlab-auth-secret \
     -n <tenant-namespace> \
     appstudio.redhat.com/credentials=scm
   ```

4. Annotate the secret with the GitLab host:

   ```bash
   oc annotate secret gitlab-auth-secret \
     -n <tenant-namespace> \
     appstudio.redhat.com/scm.host=gitlab.com
   ```

   Replace `gitlab.com` with the hostname of your GitLab instance if you are using a self-hosted instance.

### Verification

Verify that the secret was created:

```bash
oc get secret gitlab-auth-secret -n <tenant-namespace>
```

## Configure the Quay integration

Configure the Quay registry integration so that TSF can push built container images to your Quay organization.

### Prerequisites

- You have started the TSF installer container.
- You are logged in to the OCP cluster.
- You have created a Quay OAuth token with access to your Quay organization.

### Steps

1. Configure the Quay integration:

   ```bash
   tsf integration quay \
     --organization="$QUAY__ORG" \
     --token="$QUAY__API_TOKEN" \
     --url="$QUAY__URL"
   ```

> **Note:** When a new component is onboarded to Konflux, a repository is automatically created in the specified Quay organization. If you are using a free quay.io account, you must manually change the visibility of new repositories to public because of account limitations. If you are using a paid quay.io account, the repositories can remain private.

### Verification

Verify that the Quay integration secret was created in the `tsf` namespace:

```bash
oc get secret tsf-quay-integration -n tsf
```

The output should show the `tsf-quay-integration` secret of type `Opaque`.

## Deploy TSF

Deploy all TSF services to your OCP cluster. This step installs and configures all components of the software factory using Helm charts.

### Prerequisites

- You have started the TSF installer container.
- You are logged in to your OCP cluster with `cluster-admin` access.
- You have created the TSF configuration on the cluster.
- You have configured the GitHub or GitLab integration and the Quay integration.

### Steps

1. Deploy all TSF services:

   ```bash
   tsf deploy
   ```

   The deployment process installs 9 Helm charts sequentially, creating the following OCP projects:

   - `cert-manager-operator`
   - `konflux-operator`
   - `konflux-ui`
   - `openshift-storage`
   - `rhbk-operator`
   - `rhtpa-operator`
   - `tssc-keycloak`
   - `tssc-quay`
   - `tsf-tas`
   - `tsf-tpa`

   > **Note:** The deployment typically takes about 15 minutes. Some charts may take several minutes without producing output. This is expected behavior. If deployment fails, you can re-run the `tsf deploy` command. The installer attempts to deploy all charts, including those that previously succeeded.

2. Monitor the command output. As the deployment progresses, the CLI prints the status of each Helm chart, including:
   - Chart name, version, and namespace
   - Service URLs for Konflux, Red Hat Trusted Artifact Signer (Fulcio, Rekor, TUF), and Red Hat Trusted Profile Analyzer

3. Save the deployment output for future reference, particularly the service URLs displayed at the end.

   The deployment finishes with:

   ```
   Deployment complete!
   ```

## Next step

Proceed to [Verifying and accessing Trusted Software Factory](verifying-and-accessing.md).
