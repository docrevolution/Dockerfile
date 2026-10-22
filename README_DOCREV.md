# DocRev Docker images

Build script for the DocRev PHP images, with optional push to AWS ECR.

## Prerequisites

- Docker
- AWS CLI v2
- Valid AWS session. We use AWS SSO, so run `aws sso login` if your session expired:

  ```bash
  aws sso login
  ```

- (Recommended) The [Amazon ECR Docker Credential Helper](https://github.com/awslabs/amazon-ecr-credential-helper)
  (`docker-credential-ecr-login`). If installed and configured in `~/.docker/config.json`
  (`"credsStore": "ecr-login"`), no `docker login` is needed — the helper fetches a fresh
  token from your SSO session automatically on every push. Without it, the script falls
  back to `aws ecr get-login-password | docker login`.

## Usage

```bash
./build-local-docrev.sh          # build PHP 8.2 images + push php-nginx to ECR
./build-local-docrev.sh 8.4      # build & push for PHP 8.4
PUSH_ECR=0 ./build-local-docrev.sh 8.2   # build locally only, no push
```

The first argument selects the PHP version; it must exist as `docker/php/<version>`.

## What the script does

1. Builds two local images:
   - `docrev/php:<version>-alpine`
   - `docrev/php-nginx:<version>-alpine`
2. If `PUSH_ECR=1` (default):
   - Authenticates to ECR (via credential helper or `get-login-password`)
   - Creates the ECR repository `docrev/php-nginx` if it does not exist yet
   - Tags and pushes only `docrev/php-nginx` to:

     ```
     267166554494.dkr.ecr.eu-west-1.amazonaws.com/docrev/php-nginx:<version>-alpine
     ```

## Configuration

All settings can be overridden via environment variables:

| Variable         | Default                                        | Description                          |
|------------------|------------------------------------------------|--------------------------------------|
| `AWS_ACCOUNT_ID` | `267166554494`                                 | AWS account ID                       |
| `AWS_REGION`     | `eu-west-1`                                    | AWS region                           |
| `ECR_REGISTRY`   | `<account>.dkr.ecr.<region>.amazonaws.com`     | ECR registry host                    |
| `PUSH_ECR`       | `1`                                            | Set to `0` to skip pushing           |

Example:

```bash
AWS_REGION=eu-central-1 PUSH_ECR=0 ./build-local-docrev.sh 8.2
```

## IAM permissions

The identity used (SSO role) needs:

- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`, `ecr:CompleteLayerUpload`, `ecr:InitiateLayerUpload`, `ecr:PutImage`, `ecr:UploadLayerPart` (push)
- `ecr:DescribeRepositories`, `ecr:CreateRepository` (repo existence check / auto-create)

The `AdministratorAccess` managed role covers all of these. For least privilege, use
`AmazonEC2ContainerRegistryPowerUser` plus a scoped `ecr:CreateRepository`/`DescribeRepositories`
on the `docrev/*` repositories.

## Troubleshooting

**`error saving credentials: error storing credentials - err: exit status 1, out: 'not implemented'`**

This means Docker tried to store the ECR token in the `ecr-login` credential helper, which
does not support storing passwords (tokens are short-lived and fetched on demand). The script
avoids `docker login` when the helper is installed. If you hit this manually, either install
the helper or run `docker login` without storing (the token is only needed for the current
session).

**`not authorized / access denied` on push**

Your SSO session likely expired. Run `aws sso login` and retry.

**Repository not found errors**

The script auto-creates `docrev/php-nginx`, but that requires `ecr:CreateRepository`
permission. If your role lacks it, create it once manually:

```bash
aws ecr create-repository --repository-name docrev/php-nginx --region eu-west-1
```

## References

- [Pushing a Docker image to Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html)
- [Private registry authentication in Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html)
- [Amazon ECR Docker Credential Helper](https://github.com/awslabs/amazon-ecr-credential-helper)
