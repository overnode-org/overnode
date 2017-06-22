resource "docker_container" "{SERVICE_NAME}-{NODE_ID}" {
  provider = "docker.node-{NODE_ID}"

  image = "{SERVICE_IMAGE}"
  name  = "{SERVICE_NAME}"
  {COMMAND_CUSTOM}
  env = [
    "WEAVE_CIDR={CONTAINER_IP}/12",
    "CONTAINER_IP={CONTAINER_IP}",
    "CONTAINER_NAME={SERVICE_NAME}",
    "SERVICE_NAME={SERVICE_NAME}.clusterlite.local"{ENV_PUBLIC_HOST_IP}{ENV_SERVICE_SEEDS}{ENV_DEPENDENCIES}{ENV_CUSTOM}
  ]
  restart = "always"
  hostname = "{SERVICE_NAME}.clusterlite.local"
  ports = [{PORTS_CUSTOM}]
  destroy_grace_seconds = 30
  volumes = [{VOLUME_CUSTOM}]

  # TODO question asked: about /w/w
  # https://github.com/weaveworks/weave/issues/3026
  # remaining args: --init \ init can be worked around
  #entrypoint = ["/usr/bin/docker-init", "-s", "--"]
}