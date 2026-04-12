---
name: app-service
description: Deploy and update Azure App Service web apps with `az webapp up`, zip artifacts, app settings, and live logs. Use when a long-running HTTP app should run on Azure's managed web hosting surface.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# app-service

Use this skill when the workload is a web app rather than a function or Kubernetes deployment.

## When to Use

- The agent has a project directory and wants a one-command App Service deployment
- CI already built a zip artifact for an existing web app
- Application settings need to change without a full redeploy
- Live log streaming is needed during rollout verification

## Workflow

1. Confirm resource group, subscription, and target app name.
2. Use `up` when deploying from a working tree; use `deploy-zip` for built artifacts.
3. Push only the required app settings and keep true secrets in Key Vault.
4. Tail logs or inspect Monitor immediately after deployment.

## Examples

~~~bash
AZURE_APP_SERVICE_ACTION=up \
AZURE_RESOURCE_GROUP=rg-dojo-web \
AZURE_LOCATION=eastus \
AZURE_WEBAPP_NAME=dojo-web-prod \
AZURE_WEBAPP_RUNTIME=PYTHON:3.12 \
AZURE_WEBAPP_SRC_PATH=./apps/web \
./scripts/deploy-webapp.sh

AZURE_APP_SERVICE_ACTION=deploy-zip \
AZURE_RESOURCE_GROUP=rg-dojo-web \
AZURE_WEBAPP_NAME=dojo-web-prod \
AZURE_WEBAPP_ARTIFACT_PATH=./dist/app.zip \
./scripts/deploy-webapp.sh
~~~

## Edge Cases

- `az webapp up` must run from the project directory and writes defaults into `.azure/config`.
- Use zip deploy when build and deploy are separate pipeline steps.
- `log-tail` is long-running and intended for interactive verification, not batch output parsing.
