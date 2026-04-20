#!/bin/bash

REGISTRY="docker.io"
IMAGE_NAME="python-energymeter"
TAG="0.1.4"                                       # TODO edit this
DOCKERHUB_USERNAME="<your-dockerhub-user>"        # TODO edit this
IMAGEFILENAME="python-server.Dockerfile"

podman login $REGISTRY
if [ $? -ne 0 ]; then
    echo "Failed to login to $REGISTRY. Please check your credentials."
    exit 1
fi

# build and push the image
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    podman build -f $IMAGEFILENAME -t $DOCKERHUB_USERNAME/$IMAGE_NAME:$TAG .
    podman tag $DOCKERHUB_USERNAME/$IMAGE_NAME:$TAG $REGISTRY/$DOCKERHUB_USERNAME/$IMAGE_NAME:$TAG
    podman push $REGISTRY/$DOCKERHUB_USERNAME/$IMAGE_NAME:$TAG
    # update also the "latest" tag
    podman tag $DOCKERHUB_USERNAME/$IMAGE_NAME:$TAG $DOCKERHUB_USERNAME/$IMAGE_NAME:latest
    podman tag $DOCKERHUB_USERNAME/$IMAGE_NAME:latest $REGISTRY/$DOCKERHUB_USERNAME/$IMAGE_NAME:latest
    podman push $REGISTRY/$DOCKERHUB_USERNAME/$IMAGE_NAME:latest
elif [[ "$OSTYPE" == "darwin"* ]]; then
    MANIFEST="${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${TAG}"
    # double build
    podman build \
      --platform linux/amd64,linux/arm64 \
      --manifest "${MANIFEST}" \
      -f "${IMAGEFILENAME}" .
    podman manifest push --all "${MANIFEST}" "docker.io/${MANIFEST}"
    # update also the "latest" tag
    MANIFEST_LATEST="${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"
    podman manifest create "${MANIFEST_LATEST}" --amend "${MANIFEST}"
    podman manifest push --all "${MANIFEST_LATEST}" "docker.io/${MANIFEST_LATEST}"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

