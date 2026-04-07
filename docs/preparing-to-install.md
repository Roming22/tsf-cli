# Preparing to install Trusted Software Factory

Before installing Trusted Software Factory (TSF), prepare your environment by verifying that your cluster meets the requirements, setting up accounts on GitHub and Quay.io, and collecting all credentials into an environment file.

Completing these preparation steps before starting the installation avoids interruptions during the deployment process.

## Prerequisites

### Cluster requirements

- An OpenShift Container Platform cluster running version 4.20 or later.
- The cluster must be a fresh installation with no other production workloads running on it. The installer assumes full control of deploying and configuring all dependencies.
- A minimum 3-node standard deployment of OCP. Single Node OpenShift (SNO) is not supported.
- `cluster-admin` access to the OCP cluster.

> **Tip:** If you do not have an OCP cluster, you can provision one from the [Red Hat Demo Platform](https://catalog.demo.redhat.com) or install [OpenShift Local](https://developers.redhat.com/products/openshift-local/overview) for local development.

### Source control requirements

TSF supports GitHub and GitLab as source control management systems. You need one of the following:

**GitHub:**

- A GitHub organization. If you do not have one, [create a test organization](https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/creating-a-new-organization-from-scratch) before proceeding.
- The ability to create a GitHub App in your organization. The installer creates the GitHub App automatically, which requires the following permissions:
  - Read access to members, metadata, and organization plan
  - Read and write access to administration, checks, code, issues, pull requests, and workflows

**GitLab:**

- A GitLab instance with bidirectional network connectivity to the OCP cluster. The cluster must reach the GitLab instance, and the GitLab instance must send webhook events to the cluster.
- The ability to create a Project Access Token with the **Maintainer** role and the following scopes:
  - `api`
  - `read_repository`
  - `write_repository`

### Artifact registry requirements

- A Quay.io account with access to an organization. Currently, only quay.io is supported. Support for other Quay instances is planned for a future release.

### Local system requirements

- The `oc` command-line tool installed on your local system. For installation instructions, see [Getting started with the OpenShift CLI](https://docs.openshift.com/container-platform/4.20/cli_reference/openshift_cli/getting-started-cli.html).
- Podman installed on your local system. Docker should also work, but it is not a tested workflow.

> **Important:** The TSF installer generates your first deployment but does not support upgrades. Each product must be manually reconfigured for production workloads. The installer is intended as a day-zero, one-time activity.

## Creating a Quay organization and OAuth token

Create a Quay.io organization and generate an OAuth token. The TSF installer uses this token to create repositories for your built container images.

### Steps

1. Log in to [quay.io](https://quay.io).

2. If you do not already have a Quay.io organization, create one:
   1. On the Quay.io homepage, click **Create New Organization**.
   2. Enter a name for the organization, for example, `tsf-install`.
   3. Click **Create Organization**.

3. Navigate to your organization page and click the **Applications** icon on the left-hand side.

4. Click **Create New Application** and enter a name for the application, for example, `tsf`.

5. Click the name of the newly created application.

6. Click **Generate Token**.

7. Select all permission scopes.

8. Click **Generate Access Token**.

9. Click **Authorize Application**.

10. Copy the access token and save it securely. Use this token in the next step when preparing the environment file.

### Verification

The access token is displayed on the screen and can be copied. Save it in a secure location before closing the page.

## Preparing the environment file

Create an environment file that contains the credentials and configuration for your OCP cluster, GitHub organization, and Quay registry. The TSF installer reads this file to configure all integrations.

### Steps

1. Create a file named `tsf.env` in your working directory with the following content:

   ```bash
   # github.com
   GITHUB__ORG=<your_github_organization>

   # OpenShift
   OCP__API_ENDPOINT=<your_cluster_api_url>
   OCP__USERNAME=<your_cluster_admin_username>
   OCP__PASSWORD=<your_cluster_admin_password>

   # quay.io
   QUAY__API_TOKEN=<your_quay_oauth_token>
   QUAY__ORG=<your_quay_organization>
   QUAY__URL=https://quay.io
   ```

2. Replace each placeholder with the values from your environment:

   | Variable | Description |
   |----------|-------------|
   | `GITHUB__ORG` | The name of the GitHub organization to use with TSF. |
   | `OCP__API_ENDPOINT` | The full URL of the OCP cluster API endpoint. For example: `https://api.example.com:6443`. |
   | `OCP__USERNAME` | A user with `cluster-admin` privileges on the cluster. |
   | `OCP__PASSWORD` | The password for the cluster administrator user. |
   | `QUAY__API_TOKEN` | The OAuth token you generated for your Quay organization. |
   | `QUAY__ORG` | The name of the Quay organization that the token provides access to. |
   | `QUAY__URL` | The full URL of the Quay registry. Use `https://quay.io`. |

3. Save the file.

> **Note:** When you start the installer container in the next phase, ensure you run the `podman` command from the directory that contains this `tsf.env` file.

## Next step

Proceed to [Installing Trusted Software Factory](installing.md).
