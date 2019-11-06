#!/bin/bash

set -euo pipefail

push_flag='false'
registry='descartesresearch'
latest='false'
no_cache='false'
tag="$(git branch --show-current)-$(git rev-parse --short HEAD)"

print_usage() {
  printf "Usage: docker_build.sh [-p] [-r REGISTRY_NAME] [-t tag] [-l]\n"
}

while getopts 'npltr:' flag; do
  case "${flag}" in
    n) no_cache="true" ;;
    p) push_flag='true' ;;
    l) latest='true' ;;
    t) tag="${OPTARG}" ;;
    r) registry="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done

if ! [ -z "$(git status --porcelain)" ]; then
  printf "ERROR Git repo status not clean (uncommitted changes or files) so refusing to build Docker images\n"
  exit 1
fi

pushd ..
mvn install -DskipTests
popd

docker build --pull --no-cache=${no_cache} -t "$registry/teastore-base:${tag}" ../utilities/tools.descartes.teastore.dockerbase/
if [[ "$latest" == "true" ]]; then
  docker tag "${registry}/teastore-base:${tag}" "${registry}/teastore-base:latest"
fi

for service in registry persistence image webui auth recommender; do
  perl -i -pe's|.*FROM descartesresearch/teastore-base.*|FROM '"$registry/teastore-base:${tag}"'|g' ../services/tools.descartes.teastore.${service}/Dockerfile
  docker build -t "${registry}/teastore-${service}:${tag}" ../services/tools.descartes.teastore.${service}/
  if [[ "$latest" == "true" ]]; then
    docker tag "${registry}/teastore-${service}:${tag}" "${registry}/teastore-${service}:latest"
  fi
  # Safe to checkout since we are sure that no uncommitted changes can be present in repo
  git checkout -- ../services/tools.descartes.teastore.${service}/Dockerfile
done

if [ "$push_flag" = 'true' ]; then
  for image in base registry persistence image webui auth recommender; do
    docker push "${registry}/teastore-${image}:${tag}"
    if [[ "$latest" == "true" ]]; then
      docker push "${registry}/teastore-${image}:latest"
    fi
  done
fi
