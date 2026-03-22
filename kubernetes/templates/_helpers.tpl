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
