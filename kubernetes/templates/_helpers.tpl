{{/*
Expand the name of the chart.
*/}}
{{- define "webdav.name" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "webdav.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "webdav.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "webdav.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webdav.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Detect OpenShift by the presence of its SecurityContextConstraints API group.
Returns "true" on OpenShift, "" otherwise.
*/}}
{{- define "webdav.isOpenShift" -}}
{{- if .Capabilities.APIVersions.Has "security.openshift.io/v1" -}}true{{- end -}}
{{- end }}

{{/*
Pod-level securityContext.
On OpenShift the restricted-v2 SCC assigns a random UID/GID from the namespace
range and rejects a pinned runAsUser/fsGroup — and the image already supports
arbitrary UIDs — so we omit those fields there. On plain Kubernetes we pin them
to the values (the image's 'webuser' UID 999).
*/}}
{{- define "webdav.podSecurityContext" -}}
runAsNonRoot: {{ .Values.podSecurityContext.runAsNonRoot }}
{{- with .Values.podSecurityContext.seccompProfile }}
seccompProfile:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if not (include "webdav.isOpenShift" .) }}
{{- with .Values.podSecurityContext.runAsUser }}
runAsUser: {{ . }}
{{- end }}
{{- with .Values.podSecurityContext.runAsGroup }}
runAsGroup: {{ . }}
{{- end }}
{{- with .Values.podSecurityContext.fsGroup }}
fsGroup: {{ . }}
{{- end }}
{{- end }}
{{- end }}
