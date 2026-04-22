# Settings
{{- $crc := required "CRC settings" .Installer.Settings.crc -}}

# Products settings
{{- $certManager := required "Cert-Manager settings" .Installer.Products.Cert_Manager -}}
{{- $certManagerNamespace := "cert-manager-operator" -}}
{{- $konflux := required "Konflux settings" .Installer.Products.Konflux -}}
{{- $pipelines := required "Pipelines settings" .Installer.Products.OpenShift_Pipelines -}}
{{- $pipelinesNamespace := "openshift-pipelines" -}}
{{- $tas := required "TAS settings" .Installer.Products.Trusted_Artifact_Signer -}}
{{- $tpa := required "TPA settings" .Installer.Products.Trusted_Profile_Analyzer -}}

{{- $keycloakEnabled := or $tpa.Enabled $tas.Enabled -}}
{{- $keycloakNamespace := "tsf-keycloak" -}}

# Cluster settings
{{- $ingressDomain := required "OpenShift ingress domain" .OpenShift.Ingress.Domain -}}
{{- $ingressRouterCA := required "OpenShift RouterCA" .OpenShift.Ingress.RouterCA -}}
{{- $openshiftMinorVersion := required "OpenShift Version" .OpenShift.MinorVersion -}}



---
debug:
  ci: {{ dig "ci" "debug" false .Installer.Settings }}

#
# tsf-openshift
#

openshift:
  projects:
{{- if $certManager.Enabled }}
    - {{ $certManagerNamespace }}
{{- end }}
{{- if $keycloakEnabled }}
    - {{ $keycloakNamespace }}
    - rhbk-operator
{{- end }}
{{- if $konflux.Enabled }}
    - {{ $konflux.Namespace }}
    - konflux-operator
{{- end }}
{{- if $tas.Enabled }}
    - {{ $tas.Namespace }}
{{- end }}
{{- if $tpa.Enabled }}
    - {{ $tpa.Namespace }}
    {{- $tpaMS := dig "manageSubscription" "false" ($tpa.Properties | default dict) -}}
    {{- if ne $tpaMS "false" }}
    - rhtpa-operator
    {{- end }}
{{- end }}

#
# tsf-subscriptions
#


subscriptions:
  konflux:
    enabled: {{ $konflux.Enabled }}
    managed: '{{ if $konflux.Enabled }}{{ dig "manageSubscription" "auto" ($konflux.Properties | default dict) | toString }}{{ else }}false{{ end }}'
  openshiftCertManager:
    enabled: {{ $certManager.Enabled }}
    managed: '{{ if $certManager.Enabled }}{{ dig "manageSubscription" "auto" ($certManager.Properties | default dict) | toString }}{{ else }}false{{ end }}'
  openshiftKeycloak:
    enabled: {{ $keycloakEnabled }}
    managed: '{{ $keycloakEnabled }}'
    operatorGroup:
      targetNamespaces:
        - {{ default "empty" $keycloakNamespace }}
  openshiftPipelines:
    enabled: {{ $pipelines.Enabled }}
    managed: '{{ if $pipelines.Enabled }}{{ dig "manageSubscription" "auto" ($pipelines.Properties | default dict) | toString }}{{ else }}false{{ end }}'
  openshiftTrustedArtifactSigner:
    enabled: {{ $tas.Enabled }}
    managed: '{{ if $tas.Enabled }}{{ dig "manageSubscription" "auto" ($tas.Properties | default dict) | toString }}{{ else }}false{{ end }}'
  trustedProfileAnalyzer:
    enabled: {{ $tpa.Enabled }}
    managed: '{{ if $tpa.Enabled }}{{ dig "manageSubscription" "auto" ($tpa.Properties | default dict) | toString }}{{ else }}false{{ end }}'

#
# tsf-infrastructure
#

infrastructure:
  pgsqlService:
    instances:
      - name: tpa
        enabled: {{ $tpa.Enabled }}
        namespace: {{ $tpa.Namespace }}
      - name: keycloak
        enabled: {{ $keycloakEnabled }}
        namespace: {{ $keycloakNamespace }}
  openShiftPipelines:
    enabled: {{ $pipelines.Enabled }}
    namespace: {{ $pipelinesNamespace }}

#
# tsf-iam
#

{{- $keycloakRouteTLSSecretName := "keycloak-tls" }}
{{- $keycloakRouteHost := printf "tsf-sso.%s" $ingressDomain }}
{{- $realmsName := "tsf-iam" }}
{{- $tpaTestingUsersEnabled := false }}
{{- $protocol := "https" -}}
{{- if $crc }}
  {{- $protocol = "http" }}
{{- end }}
{{- $tpaOIDCIssuerURL := printf "%s://%s/realms/%s" $protocol $keycloakRouteHost $realmsName }}
{{- $clientAlias := "ocp-federation" }}
{{- $ocpBrokerRedirectUrl := printf "%s://%s/realms/%s/broker/%s/endpoint" $protocol $keycloakRouteHost $realmsName $clientAlias }}

iam:
  enabled: {{ $keycloakEnabled }}
  namespace: {{ $keycloakNamespace }}
  integrationSecret:
    namespace: {{ .Installer.Namespace }}
  oauthClientName: keycloak-broker
  oathClientAlias: {{ $clientAlias }}
  oauthBrokerRedirectUrl: {{ $ocpBrokerRedirectUrl }}
  instances: 1
  database:
    host: keycloak-pgsql
    name: keycloak
    secretName: keycloak-pgsql-user
  route:
    host: {{ $keycloakRouteHost }}
    tls:
      enabled: {{ not $crc }}
      secretName: {{ $keycloakRouteTLSSecretName }}
      termination: reencrypt
{{- if $crc }}
    annotations:
      route.openshift.io/termination: reencrypt
{{- end }}
  service:
    annotations:
      service.beta.openshift.io/serving-cert-secret-name: {{ $keycloakRouteTLSSecretName }}
  keycloakCR:
    namespace: {{ $keycloakNamespace }}
    ingressDomain: {{ $ingressDomain }}
    trustedArtifactSignerRealm:
      enabled: {{ $tas.Enabled }}
    trustedProfileAnalyzerRealm:
      enabled: {{ $tpa.Enabled }}
      oidcIssuerURL: {{ $tpaOIDCIssuerURL }}
      clients:
        cli:
          enabled: true
        release:
          enabled: true
        testingManager:
          enabled: {{ $tpaTestingUsersEnabled }}
        testingUser:
          enabled: {{ $tpaTestingUsersEnabled }}
      frontendRedirectUris:
        - "http://localhost:8080"
    {{- range list "server" "sbom" }}
        - "{{ printf "%s://%s-%s.%s" $protocol . $tpa.Namespace $ingressDomain }}"
        - "{{ printf "%s://%s-%s.%s/*" $protocol . $tpa.Namespace $ingressDomain }}"
    {{- end }}
      integrationSecret:
        bombasticAPI: {{
          printf "%s://server-%s.%s"
            $protocol
            $tpa.Namespace
            $ingressDomain
        }}
        bombasticAPIService: {{
          printf "https://server.%s.svc.cluster.local"
            $tpa.Namespace
        }}
        namespace: {{ .Installer.Namespace }}
#
# tsf-konflux
#

konflux:
  ingressDomain: "{{ $ingressDomain }}"
  tsf:
    namespace: {{ .Installer.Namespace }}

#
# tsf-pipelines
#

pipelines:
  namespace: {{ $pipelinesNamespace }}
  ingressDomain: {{ $ingressDomain }}
  konflux:
    namespace: {{ $konflux.Namespace }}
  tsf:
    namespace: {{ .Installer.Namespace }}

#
# tsf-tpa
#

{{- $tpaDatabaseSecretName := "tpa-pgsql-user" }}
{{- $tpaAppDomain := printf "-%s.%s" $tpa.Namespace $ingressDomain }}
{{- $tpaOIDCClientsSecretName := "tpa-realm-clients" }}

trustedProfileAnalyzer:
  cycloneDXVersion: 1.4
  oidcIssuerURL: {{ $tpaOIDCIssuerURL }}
  namespace: "{{ $tpa.Namespace }}"
  appDomain: "{{ $tpaAppDomain }}"
  integrationSecret:
    namespace: {{ .Installer.Namespace }}
  ingress: &tpaIngress
    className: openshift-default
  openshift: &tpaOpenShift
    # In practice it toggles "https" vs. "http" for TPA components, for CRC it's
    # easier to focus on "http" communication only.
    useServiceCa: {{ not $crc }}
  database: &tpaDatabase
    name:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaDatabaseSecretName }}
          key: dbname
    host:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaDatabaseSecretName }}
          key: host
    port:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaDatabaseSecretName}}
          key: port
    username:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaDatabaseSecretName }}
          key: user
    password:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaDatabaseSecretName }}
          key: password
  createDatabase: *tpaDatabase
  migrateDatabase: *tpaDatabase
  storage: &tpaStorage
    type: filesystem
    size: 32Gi
  oidc: &tpaOIDC
    issuerUrl: {{ $tpaOIDCIssuerURL }}
    clients:
      cli:
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: cli
      release:
        clientId: release
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: release
        additionalPermissions:
          - "create.sbom"
          - "read.sbom"
          - "update.sbom"
{{- if $tpaTestingUsersEnabled }}
      testingUser:
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: testingUser
      testingManager:
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: testingManager
{{- end }}

#
# tsf-tas
#

{{- $tasRealmPath := printf "realms/%s" $realmsName }}

trustedArtifactSigner:
  enabled: {{ $tas.Enabled }}
  ingressDomain: "{{ $ingressDomain }}"
  secureSign:
    enabled: {{ $tas.Enabled }}
    namespace: {{ $tas.Namespace }}
    fulcio:
      oidc:
        clientID: trusted-artifact-signer
        issuerURL: {{ printf "%s://%s/%s" $protocol $keycloakRouteHost $tasRealmPath }}
      certificate:
        # TODO: prompt the user for organization email/name input!
        organizationEmail: trusted-artifact-signer@company.dev
        organizationName: TSF
  integrationSecret:
    namespace: {{ .Installer.Namespace }}
