# Preparing to install Trusted Software Factory

Before installing Trusted Software Factory (TSF), prepare your environment. Verify that your cluster meets the requirements, create accounts on GitHub and Quay, and collect all credentials into an environment file.

## Prerequisites

### Cluster requirements

- You have an OpenShift Container Platform cluster running version 4.20 or later.
- You have a fresh cluster with no other production workloads. The installer assumes full control of deploying and configuring all dependencies.
- You have a minimum 3-node standard deployment of OCP. Single Node OpenShift (SNO) is not supported.
- You have `cluster-admin` access to the OCP cluster.

> **Tip:** If you do not have an OCP cluster, you can provision one from the [Red Hat Demo Platform](https://catalog.demo.redhat.com) or install [OpenShift Local](https://developers.redhat.com/products/openshift-local/overview) for local development.

### Source control requirements

TSF supports GitHub and GitLab as source control management systems. You need one of the following:

**GitHub** (only the community github.com is supported):

- You have a GitHub organization on github.com with bidirectional network connectivity to the OCP cluster. The cluster must reach github.com, and github.com must send webhook events to the cluster.
- If you do not have an organization, [create a test organization](https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/creating-a-new-organization-from-scratch) before proceeding.
- You can create a GitHub App in your organization. The installer creates the GitHub App automatically, which requires the following permissions:
  - Read access to members, metadata, and organization plan
  - Read and write access to administration, checks, code, issues, pull requests, and workflows

**GitLab:**

- You have a GitLab instance with bidirectional network connectivity to the OCP cluster. The cluster must reach the GitLab instance, and the GitLab instance must send webhook events to the cluster.
- You can create a Project Access Token with the **Maintainer** role and the following scopes:
  - `api`
  - `read_repository`
  - `write_repository`

### Artifact registry requirements

- You have a Quay registry account with access to an organization. Both quay.io and local Quay instances are supported.

### Local system requirements

- You have the `oc` command-line tool installed on your local system. For installation instructions, see [Getting started with the OpenShift CLI](https://docs.openshift.com/container-platform/4.20/cli_reference/openshift_cli/getting-started-cli.html).
- You have Podman installed on your local system. Docker is not a tested workflow.

> **Important:** The TSF installer generates your first deployment but does not support upgrades. Each product must be manually reconfigured for production workloads. The installer is intended as a day-zero, one-time activity.

## Create a Quay organization and OAuth token

Create a Quay organization and generate an OAuth token. The TSF installer uses this token to create repositories for your built container images.

Follow the Quay documentation to complete these steps:

1. [Create an organization](https://docs.quay.io/guides/create-org.html) in your Quay registry.
2. [Create an OAuth application](https://docs.quay.io/api/) within the organization and generate an access token with all permission scopes.

Copy the access token and save it securely. Use this token in the next step when preparing the environment file.

## Prepare the environment file

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

   # Quay registry
   QUAY__API_TOKEN=<your_quay_oauth_token>
   QUAY__ORG=<your_quay_organization>
   QUAY__URL=<your_quay_url>
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
   | `QUAY__URL` | The full URL of the Quay registry. For example: `https://quay.io`. |

3. Save the file.

> **Note:** When you start the installer container in the next phase, run the `podman` command from the directory that contains this `tsf.env` file.

## Next step

Proceed to [Installing Trusted Software Factory](installing.md).
