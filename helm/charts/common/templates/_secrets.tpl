{{/*
RDS 자격증명 환경변수
*/}}
{{- define "common.env.rds" -}}
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: rds-credentials
      key: host
- name: DB_PORT
  valueFrom:
    secretKeyRef:
      name: rds-credentials
      key: port
- name: DB_NAME
  valueFrom:
    secretKeyRef:
      name: rds-credentials
      key: database
- name: DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: rds-credentials
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: rds-credentials
      key: password
{{- end -}}

{{/*
Redis 자격증명 환경변수
*/}}
{{- define "common.env.redis" -}}
- name: REDIS_HOST
  valueFrom:
    secretKeyRef:
      name: redis-credentials
      key: host
- name: REDIS_PORT
  valueFrom:
    secretKeyRef:
      name: redis-credentials
      key: port
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: redis-credentials
      key: password
{{- end -}}

{{/*
JWT 시크릿 환경변수
*/}}
{{- define "common.env.jwt" -}}
- name: JWT_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: jwt-secret
      key: secret-key
{{- end -}}

{{/*
Passport 시크릿 환경변수
*/}}
{{- define "common.env.passport" -}}
- name: PASSPORT_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: passport-secret
      key: secret-key
{{- end -}}

{{/*
결제 API 키 환경변수
*/}}
{{- define "common.env.payment" -}}
- name: TOSS_PAYMENTS_CLIENT_KEY
  valueFrom:
    secretKeyRef:
      name: payment-api-keys
      key: TOSS_PAYMENTS_CLIENT_KEY
- name: TOSS_PAYMENTS_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: payment-api-keys
      key: TOSS_PAYMENTS_SECRET_KEY
{{- end -}}

{{/*
Database Users 환경변수 (서비스별 DB 사용자)
*/}}
{{- define "common.env.database-users" -}}
{{- if .Values.service }}
{{- if eq .Values.service "users" }}
- name: USER_AUTH_DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: database-users
      key: USER_AUTH_DB_USERNAME
- name: USER_AUTH_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: USER_AUTH_DB_PASSWORD
- name: USER_AUTH_FLYWAY_USERNAME
  valueFrom:
    secretKeyRef:
      name: database-users
      key: USER_AUTH_FLYWAY_USERNAME
- name: USER_AUTH_FLYWAY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: USER_AUTH_FLYWAY_PASSWORD
{{- else if eq .Values.service "order" }}
- name: ORDER_DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: database-users
      key: ORDER_DB_USERNAME
- name: ORDER_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: ORDER_DB_PASSWORD
- name: ORDER_FLYWAY_USERNAME
  valueFrom:
    secretKeyRef:
      name: database-users
      key: ORDER_FLYWAY_USERNAME
- name: ORDER_FLYWAY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: ORDER_FLYWAY_PASSWORD
{{- else if eq .Values.service "payment" }}
- name: PAYMENT_DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: database-users
      key: PAYMENT_DB_USERNAME
- name: PAYMENT_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: PAYMENT_DB_PASSWORD
- name: PAYMENT_FLYWAY_USERNAME
  valueFrom:
    secretKeyRef:
      name: database-users
      key: PAYMENT_FLYWAY_USERNAME
- name: PAYMENT_FLYWAY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: PAYMENT_FLYWAY_PASSWORD
- name: PAYMENT_MIGRATOR_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: PAYMENT_FLYWAY_PASSWORD
{{- else if eq .Values.service "stores" }}
- name: STORE_DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: database-users
      key: STORE_DB_USERNAME
- name: STORE_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: STORE_DB_PASSWORD
- name: STORE_FLYWAY_USERNAME
  valueFrom:
    secretKeyRef:
      name: database-users
      key: STORE_FLYWAY_USERNAME
- name: STORE_FLYWAY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: STORE_FLYWAY_PASSWORD
- name: STORE_MIGRATOR_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: STORE_FLYWAY_PASSWORD
{{- else if eq .Values.service "checkins" }}
- name: QR_DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: database-users
      key: QR_DB_USERNAME
- name: QR_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: QR_DB_PASSWORD
- name: QR_FLYWAY_USERNAME
  valueFrom:
    secretKeyRef:
      name: database-users
      key: QR_FLYWAY_USERNAME
- name: QR_FLYWAY_PASSWORD
  valueFrom:
    secretKeyRef:
      name: database-users
      key: QR_FLYWAY_PASSWORD
{{- end }}
{{- end }}
{{- end -}}

{{/*
모든 공통 시크릿 환경변수 (RDS + Redis + JWT + Passport)
*/}}
{{- define "common.env.all-secrets" -}}
{{- include "common.env.rds" . }}
{{- include "common.env.redis" . }}
{{- include "common.env.jwt" . }}
{{- include "common.env.passport" . }}
{{- include "common.env.database-users" . }}
{{- end -}}
