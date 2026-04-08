# Getting started with Trusted Software Factory

After installing and verifying TSF, onboard your first application to see the secure build pipeline in action. This guide walks through the developer workflow: creating an application, onboarding a component from a Git repository, triggering a build, configuring a release, and verifying signed artifacts.

**Persona:** Developer — builds and ships applications using the software factory that the Platform Engineer installed.

## Prerequisites

- TSF is [installed](installing.md) and [verified](verifying-and-accessing.md) on your OCP cluster.
- You can log in to the Konflux UI.
- You have a Git repository with source code that you want to build. If you do not have one, fork the [sample-component-golang](https://github.com/konflux-ci/sample-component-golang) repository.
- Your Git provider integration (GitHub or GitLab) is configured as part of the [installation](installing.md).

## Log in to the Konflux UI

1. Open the Konflux UI URL in a web browser.

2. Log in with your OCP credentials.

3. Authorize the `dex-client` service account when prompted.

The Konflux dashboard displays the **Get started with Konflux** landing page.

## Create an application

An application in Konflux is a logical grouping of one or more components that are built, tested, and released together.

1. In the Konflux UI, click **Create an application**.

2. Enter a name for your application, for example, `my-app`.

3. Click **Create application**.

For more details, see [Creating an application](https://konflux-ci.dev/docs/building/creating/#creating-an-application) in the Konflux documentation.

## Create a component

A component maps to a single Git repository and branch. When you create a component, Konflux onboards the repository and configures the build pipeline.

1. From your application page, click **Add component**.

2. Enter the Git repository URL for your source code. For example: `https://github.com/konflux-ci/sample-component-golang`.

3. Select the branch to build from.

4. Review the detected build pipeline and click **Create component**.

For more details, see [Creating a component](https://konflux-ci.dev/docs/building/creating/#with-the-ui-2) in the Konflux documentation.

### What happens after you create a component

After you create a component, Konflux automatically:

1. **Sends a pull request** to your Git repository. This PR adds a build pipeline definition (`.tekton/` directory) that triggers on pull request and push events targeting the onboarded branch.

2. **Configures a default integration test pipeline.** This pipeline runs automatically after each build to evaluate the artifacts against the configured policy. The integration test definition is stored as a Custom Resource in OpenShift and is not visible in your Git repository.

3. **Creates CI checks** on the pull request (GitHub checks or GitLab webhooks, depending on your Git provider). Two checks appear:
   - One for the build pipeline status
   - One for the integration test pipeline status

   You can click through to view logs and additional information.

> **Important:** Do not merge this pull request yet. Configure a release first so you can see the full end-to-end flow.

## Configure a release

By default, onboarded components are not automatically released. A Platform Engineer must configure the release criteria and destination before artifacts can be released.

The release configuration process involves creating various Custom Resources in OpenShift. Use the [setup-release.sh wrapper script](https://github.com/konflux-ci/konflux-ci/blob/main/operator/hack/setup-release.sh) to simplify this process.

Log in to the OCP cluster as the Platform Engineer (cluster admin) and run the script:

```bash
./setup-release.sh --application <application_name> --component <component_name>
```

This script creates the necessary release plan, release policy, and release pipeline resources.

## Trigger a release

After you create a component and configure a release, releases happen automatically from push events.

1. Go to your Git repository and merge the pull request that Konflux created.

2. Merging triggers a push event (commit added to the target branch), which starts another build pipeline.

3. After the build pipeline succeeds, the integration test pipeline runs automatically.

4. After both pipelines pass, navigate to the **Releases** tab in the Konflux UI. A release starts automatically.

5. Track the release progress in the UI. At the end of the release, the image is available in a Quay repository.

## Verify the build artifacts

After the build and release complete, verify the security artifacts that TSF produced:

1. **Signed container image in Quay:**
   - Navigate to your Quay organization. A new repository has been created with the built container image.
   - The image is signed using Red Hat Trusted Artifact Signer.

2. **SLSA provenance and attestation:**
   - The build produces SLSA Level 3 provenance that records how the image was built.
   - Attestations are signed and stored alongside the image.

3. **SBOM in Trusted Profile Analyzer:**
   - Open the Red Hat Trusted Profile Analyzer UI.
   - The software bill of materials (SBOM) is available, showing all packages and dependencies.
   - The UI displays vulnerability reports and license information.

4. **Signature verification:**
   - Verify the image signature using `cosign`:

     ```bash
     cosign tree <image-reference>
     ```

   - View the Rekor transparency log entry for the signing event.

## Next steps

- **Onboard more components** to build your full application stack.
- **Customize the build pipeline** by editing the `.tekton/` files in your repository.
- **Configure policy** using Conforma to enforce your organization's security requirements.
- **Configure additional integration tests** to validate your builds against custom criteria.
