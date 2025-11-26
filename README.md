# Aqua Security Scanner (Trivy Premium) Action

> [GitHub Action](https://github.com/features/actions) for [Aqua Security Scanner](https://www.aquasec.com/) (Trivy Premium)

[![License][license-img]][license]

## Table of Contents

* [Overview](#overview)
* [Quick Start](#quick-start)
* [Configuration](#configuration)
  * [Required Secrets](#required-secrets)
  * [Inputs Reference](#inputs-reference)
* [Usage Examples](#usage-examples)
  * [Basic Image Scan](#basic-image-scan)
  * [Policy-Based Registration](#policy-based-registration)
  * [SARIF Output for GitHub Security](#sarif-output-for-github-security)
  * [Complete CI/CD Pipeline](#complete-cicd-pipeline)

## Overview

This GitHub Action scans container images for vulnerabilities using **Aqua Security Scanner** (Trivy Premium).

**Key Features:**
- Integrates with Aqua SaaS platform for centralized security management
- Automatically uploads scan results to Aqua Console
- Enforces Image Assurance Policies configured in Aqua
- Registers only policy-compliant images
- Provides detailed scan logs in GitHub Actions

**Supported Output Formats:** JSON, SARIF, HTML, Table

## Quick Start

```yaml
- name: Scan with Aqua Security
  uses: andreazorzetto/trivy-premium-action@main
  with:
    aqua-registry-username: ${{ secrets.AQUA_REGISTRY_USERNAME }}
    aqua-registry-password: ${{ secrets.AQUA_REGISTRY_PASSWORD }}
    aqua-server: ${{ secrets.AQUA_SERVER }}
    aqua-token: ${{ secrets.AQUA_TOKEN }}
    scan-ref: 'my-app:${{ github.sha }}'
    image-registry-integration: 'Docker Hub'
    register-compliant: 'true'
```

## Configuration

### Required Secrets

Configure the following secrets in your GitHub repository (Settings > Secrets and variables > Actions):

| Secret | Description | Required | Example |
|--------|-------------|----------|---------|
| `AQUA_REGISTRY_USERNAME` | Your Aqua registry email/username | Yes | `user@company.com` |
| `AQUA_REGISTRY_PASSWORD` | Your Aqua registry password | Yes | `••••••••` |
| `AQUA_SERVER` | Your Aqua SaaS platform URL | No* | `https://eu-1.console.cloud.aquasec.com` |
| `AQUA_TOKEN` | Scanner token from Aqua Console | Yes | `4ea04f5b8473f626...` |

*Defaults to US region (`https://console.cloud.aquasec.com`). Set this for other regions.

#### Regional Endpoints

| Region | URL |
|--------|-----|
| US (default) | `https://console.cloud.aquasec.com` |
| EMEA | `https://eu-1.console.cloud.aquasec.com` |
| APAC | `https://asia-1.console.cloud.aquasec.com` |
| Australia | `https://ap-2.console.cloud.aquasec.com` |

### Inputs Reference

#### Authentication Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `aqua-registry-username` | Yes | - | Username for registry.aquasec.com |
| `aqua-registry-password` | Yes | - | Password for registry.aquasec.com |
| `aqua-server` | No | `https://console.cloud.aquasec.com` | Aqua SaaS platform URL (see Regional Endpoints above) |
| `aqua-token` | Yes | - | Scanner authentication token |
| `scanner-version` | No | `saas-latest` | Aqua scanner image version (use `saas-latest` for latest or pin to specific version like `2510.5.12`) |

#### Scanner Behavior (Optional)

| Input | Default | Description |
|-------|---------|-------------|
| `image-registry-integration` | `''` | Registry name in Aqua (e.g., "Docker Hub", "ECR") |
| `register-compliant` | `false` | Only register images that pass Aqua policies |
| `scan-local` | `true` | Scan locally built images (not yet pushed to registry) |

#### Scan Target & Output (Optional)

| Input | Default | Description |
|-------|---------|-------------|
| `scan-ref` | `.` | Target image to scan (image name) |
| `format` | `table` | Output format: `table`, `json`, `sarif`, `html` |
| `output` | - | File path to save scan results |

## Usage Examples

### Basic Image Scan

```yaml
- name: Build image
  run: docker build -t my-app:${{ github.sha }} .

- name: Scan with Aqua Security
  uses: andreazorzetto/trivy-premium-action@main
  with:
    aqua-registry-username: ${{ secrets.AQUA_REGISTRY_USERNAME }}
    aqua-registry-password: ${{ secrets.AQUA_REGISTRY_PASSWORD }}
    aqua-server: ${{ secrets.AQUA_SERVER }}
    aqua-token: ${{ secrets.AQUA_TOKEN }}
    scan-ref: 'my-app:${{ github.sha }}'
    image-registry-integration: 'Docker Hub'
```

### Policy-Based Registration

```yaml
- name: Scan and register compliant image
  uses: andreazorzetto/trivy-premium-action@main
  with:
    aqua-registry-username: ${{ secrets.AQUA_REGISTRY_USERNAME }}
    aqua-registry-password: ${{ secrets.AQUA_REGISTRY_PASSWORD }}
    aqua-server: ${{ secrets.AQUA_SERVER }}
    aqua-token: ${{ secrets.AQUA_TOKEN }}
    scan-ref: 'my-app:${{ github.sha }}'
    image-registry-integration: 'Docker Hub'
    register-compliant: 'true'  # Only register if policies pass
```

### SARIF Output for GitHub Security

```yaml
- name: Scan and generate SARIF
  uses: andreazorzetto/trivy-premium-action@main
  with:
    aqua-registry-username: ${{ secrets.AQUA_REGISTRY_USERNAME }}
    aqua-registry-password: ${{ secrets.AQUA_REGISTRY_PASSWORD }}
    aqua-server: ${{ secrets.AQUA_SERVER }}
    aqua-token: ${{ secrets.AQUA_TOKEN }}
    scan-ref: 'my-app:${{ github.sha }}'
    format: 'sarif'
    output: 'aqua-results.sarif'

- name: Upload to GitHub Security
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: 'aqua-results.sarif'
```

### Complete CI/CD Pipeline

```yaml
name: Build and Deploy
on:
  push:
    branches: [main]

env:
  IMAGE_NAME: my-org/my-app
  REGISTRY_INTEGRATION: Docker Hub

jobs:
  build-scan-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t $IMAGE_NAME:${{ github.sha }} .

      - name: Scan with Aqua
        uses: andreazorzetto/trivy-premium-action@main
        with:
          aqua-registry-username: ${{ secrets.AQUA_REGISTRY_USERNAME }}
          aqua-registry-password: ${{ secrets.AQUA_REGISTRY_PASSWORD }}
          aqua-server: ${{ secrets.AQUA_SERVER }}
          aqua-token: ${{ secrets.AQUA_TOKEN }}
          scan-ref: ${{ env.IMAGE_NAME }}:${{ github.sha }}
          image-registry-integration: ${{ env.REGISTRY_INTEGRATION }}
          register-compliant: 'true'

      - name: Push image
        run: |
          docker tag $IMAGE_NAME:${{ github.sha }} $IMAGE_NAME:latest
          docker push $IMAGE_NAME:${{ github.sha }}
          docker push $IMAGE_NAME:latest
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

[license-img]: https://img.shields.io/badge/License-Apache%202.0-blue.svg
[license]: LICENSE
