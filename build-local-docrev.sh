#!/usr/bin/env bash

set -exuo pipefail

ROOT_DIR=$(pwd)
PHP_VERSION=8.2

# ECR push settings (override via environment, e.g. ECR_REGISTRY=... AWS_REGION=...)
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-267166554494}
AWS_REGION=${AWS_REGION:-eu-west-1}
ECR_REGISTRY=${ECR_REGISTRY:-$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com}
PUSH_ECR=${PUSH_ECR:-1}   # set PUSH_ECR=0 to only build locally

#docker run --rm -ti -v $PWD:/app -w /app webdevops/dockerfile-build-env make provision

# if first parameter is present overwrite php version + make sanity check

if [ "$#" -gt 0 ]; then
    PHP_VERSION=$1
    if [ ! -d "docker/php/$PHP_VERSION" ]; then
        echo "PHP version $PHP_VERSION not found"
        exit 1
    fi
fi

# alpine
docker build -t docrev/php:$PHP_VERSION-alpine docker/php/$PHP_VERSION-alpine
docker build -t docrev/php-nginx:$PHP_VERSION-alpine docker/php-nginx/$PHP_VERSION-alpine

# push to ECR
if [ "$PUSH_ECR" = "1" ]; then
    # With docker-credential-ecr-login configured in ~/.docker/config.json,
    # no 'docker login' is needed: the helper fetches a short-lived token
    # from the current AWS (SSO) session automatically on push.
    if ! command -v docker-credential-ecr-login >/dev/null 2>&1; then
        aws ecr get-login-password --region "$AWS_REGION" \
            | docker login --username AWS --password-stdin "$ECR_REGISTRY"
    fi

    image=php-nginx
    repo=docrev/$image
    tag=$ECR_REGISTRY/$repo:$PHP_VERSION-alpine

    # create the repository if it does not exist yet
    if ! aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$repo" >/dev/null 2>&1; then
        echo "Creating ECR repository $repo"
        aws ecr create-repository --region "$AWS_REGION" --repository-name "$repo"
    fi

    docker tag docrev/$image:$PHP_VERSION-alpine "$tag"
    docker push "$tag"
fi

docker images | grep docrev | grep $PHP_VERSION
