{{- define "todolist-app.name" -}}todolist-app{{- end -}}
{{- define "todolist-app.fullname" -}}{{- printf "%s-%s" .Release.Name "todolist-app" | trunc 253 | trimSuffix "-" -}}{{- end -}}
{{- define "todolist-app.chart" -}}{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 254 -}}{{- end -}}
{{- define "todolist-app.serviceAccountName" -}}{{- .Values.serviceAccount.name | default (include "todolist-app.fullname" .) -}}{{- end -}}

{{/*
Full app image tag.
*/}}
{{- define "todolist-app.image" -}}
  {{- .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}
{{- end -}}
