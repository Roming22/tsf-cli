# Plan: `manageSubscription: auto` for Cert-Manager (TSF installer)

## Context

The TSF CLI (`tsf`) is built on the vendored [helmet](https://github.com/redhat-appstudio/helmet) framework (`vendor/github.com/redhat-appstudio/helmet`). Installer config lives in the `tsf-config` ConfigMap (YAML root key `tsf`). Product options are unstructured (`Properties map[string]interface{}` in `vendor/.../config/product.go`).

Today, `manageSubscription` is a boolean in `installer/config.yaml` and flows into `installer/values.yaml.tpl`, which sets `subscriptions.openshiftCertManager.managed` to `and $certManager.Enabled $certManager.Properties.manageSubscription`. The chart `installer/charts/tsf-subscriptions` only renders `Subscription` objects when `managed` is true (`templates/_subscriptions.tpl` → `subscriptions.managed`).

**Documented pain:** If Red Hat cert-manager is already on the cluster, Helm upgrade fails because an existing `Subscription` `openshift-cert-manager-operator` in `cert-manager-operator` lacks Helm ownership metadata (see `docs/trusted-software-factory.md` troubleshooting). Users must manually set `manageSubscription: false`.

**Risk if `auto` is naïve:** In Go `text/template`, a non-empty string such as `"auto"` is truthy. If the template keeps using `and ... $certManager.Properties.manageSubscription` unchanged, `manageSubscription: auto` would behave like `true` and **not** fix the conflict. Any implementation must resolve `auto` to a concrete boolean **before** values are rendered, or change the template to use an explicit boolean only.

## Goal

1. Support **`manageSubscription: auto`** (string sentinel) for the **Cert-Manager** product so the installer chooses whether to manage the operator subscription without manual ConfigMap edits.
2. **`tsf deploy` must be safe to re-run** (and the same for any wrapper such as “tssc deploy” if it invokes the same installer): if a **previous** TSF deploy created/adopted the subscription under the `tsf-subscriptions` Helm release, **subsequent runs must keep managing it** (still render/manage that subscription path), not flip to “external” and break upgrades or drift from stored intent.

## Desired semantics for `auto` (Cert-Manager)

When Cert-Manager is **enabled** and `manageSubscription` is `auto`, compute an **effective boolean** `manageSubscriptionEffective` used only for rendering (and downstream Helm values), while optionally **leaving the ConfigMap YAML as `auto`** for the user.

**Cluster inspection** (align names with `installer/charts/tsf-subscriptions/values.yaml`):

- Namespace: `cert-manager-operator`
- Subscription name: `openshift-cert-manager-operator`

**Decision table:**

1. **Subscription does not exist** → `manageSubscriptionEffective = true` (TSF may install and own it).
2. **Subscription exists** and is **owned by this TSF Helm release** → `manageSubscriptionEffective = true`. Treat as “we already manage this” so redeploys stay consistent. Ownership should match what Helm expects when the resource is part of release `tsf-subscriptions` in the installer namespace (see existing error text in docs): e.g. labels/annotations such as `app.kubernetes.io/managed-by: Helm`, `meta.helm.sh/release-name: tsf-subscriptions`, and `meta.helm.sh/release-namespace: <installer namespace>` (confirm exact values from a successful install or Helm source of truth in this repo).
3. **Subscription exists** and **does not** carry that ownership (pre-existing / other installer) → `manageSubscriptionEffective = false` (avoid Helm adoption failure; same outcome as today’s manual workaround).

**Explicit `true` / `false`:** Must continue to behave as today (no cluster override unless you deliberately add an optional “force” mode—out of scope unless requested).

## Idempotency and re-execution (hard requirement)

- After a **successful** first deploy where TSF created the subscription, the live object should have Helm metadata. The next `tsf deploy` must take **branch (2)** above and keep `managed: true`.
- After a cluster already had an **external** subscription, **branch (3)** applies on every run until that subscription is removed or ownership changes; ConfigMap can still say `auto` without forcing users to edit it.

Document edge cases for implementers: API errors during GET (fail closed vs warn—recommend **fail deploy with clear error** to avoid accidental wrong mode); partial failed installs (subscription exists but missing Helm labels—may look “external”; note in troubleshooting).

## Implementation approach (recommended)

### A. Resolve `auto` in Go with cluster context, then render values

- Hook runs **after** config is loaded and **before** `engine` renders `values.yaml.tpl` (today: `installer.SetValues` → `variables.SetInstaller(cfg)` in `vendor/.../installer/installer.go`).
- Implement a small, testable function, e.g. `ResolveManageSubscription(ctx, kube, installerNS, product string, raw any) (bool, error)`, starting with **Cert-Manager** only.
- Operate on a **copy** of config or patch the in-memory `Properties` map so `manageSubscription` becomes a **bool** for the template pass, **or** add a dedicated template field (e.g. `EffectiveManageSubscription` on the product) that `values.yaml.tpl` must use—pick one approach and use it consistently so templates never see raw `"auto"` as truthy.

### B. Where to place code

- Prefer **TSF-owned code** (e.g. new package under the CLI repo) if helmet can be extended via hooks or a thin forked patch to `SetValues`.
- If the only practical path is **vendored helmet**, document the minimal patch (e.g. optional callback or TSF-specific pre-render step) and plan to upstream later.

### C. Template / chart changes

- Update `installer/values.yaml.tpl` so Cert-Manager’s `subscriptions.openshiftCertManager.managed` uses the **resolved boolean**, not a raw property that could be a string.
- Any other use of `manageSubscription` for Cert-Manager in that file (e.g. openshift projects lists—Cert-Manager only adds `cert-manager-operator` project when enabled, not gated by manageSubscription today) should be reviewed for consistency; only change what’s necessary.

### D. Defaults and samples

- Update `installer/config.yaml` to document and optionally default Cert-Manager to `manageSubscription: auto` (product decision).
- Update `docs/trusted-software-factory.md`: replace manual step 5 with “use `auto` (default)” and keep a short note that `false` is for forcing non-management when needed.

### E. Validation

- `Product.Validate()` in helmet does not type-check `properties`. If strict validation is desired, add TSF-side validation: allow `manageSubscription` ∈ `{true, false, "auto"}` for Cert-Manager only; reject unknown types/strings.

## Testing

- **Unit tests** for the resolver with fake clients / recorded objects: absent subscription; subscription with full Helm labels; subscription without Helm labels; wrong release name/namespace.
- **Integration or e2e** (if feasible): deploy twice against a cluster where TSF owns the subscription; ensure no Helm error on second run.
- **Regression:** `manageSubscription: false` with pre-existing subscription still skips management; `true` on empty cluster still installs.

## Documentation / UX

- Explain `auto` in installer docs and troubleshooting (replace workaround steps where appropriate).
- Log at INFO/DEBUG the resolved mode (“cert-manager manageSubscription: auto → false (existing non-Helm subscription)”) to simplify support.

## Out of scope (unless expanded)

- Applying the same `auto` pattern to Konflux, Pipelines, TAS, TPA (same Helm conflict class); the design should be **extensible** (shared resolver helper, per-product subscription identity in `tsf-subscriptions/values.yaml`).

## Deliverables checklist

- [ ] Resolver logic + ownership rules aligned with `tsf-subscriptions` release name/namespace.
- [ ] Pre-render integration so templates never treat `"auto"` as boolean true.
- [ ] `installer/config.yaml` + `installer/values.yaml.tpl` updates.
- [ ] `docs/trusted-software-factory.md` updates (quickstart + troubleshooting).
- [ ] Tests and brief release note or changelog entry if the project uses one.

## Reference paths

- `installer/values.yaml.tpl`
- `installer/charts/tsf-subscriptions/values.yaml`
- `vendor/github.com/redhat-appstudio/helmet/internal/installer/installer.go`
- `docs/trusted-software-factory.md`

## Note on “tssc deploy”

If that is a separate entrypoint, verify it calls the same `tsf deploy` / helmet deploy path so this behavior applies identically.
