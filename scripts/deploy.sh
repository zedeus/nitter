#!/bin/sh
docker build -t $IMAGE_NAME . \
&& echo $DOCKERHUB_PASSWORD | docker login -u $DOCKERHUB_USERNAME --password-stdin \
&& docker push $IMAGE_NAME:latest
