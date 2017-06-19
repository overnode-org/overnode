resource "docker_image" "{SERVICE_NAME}-{NODE_ID}" {
  provider = "docker.{NODE_ID}"

  name = "{SERVICE_IMAGE}" # todo, deletion causes an error, because containers are being deleted at the same time
  # modification also causes hangs

  # see keep local params
  # see dynamic usage, which can trigger pull on change
}

resource "docker_container" "{SERVICE_NAME}-{NODE_ID}" {
  provider = "docker.{NODE_ID}"

  image = "${docker_image.{SERVICE_NAME}-{NODE_ID}.name}"
  name  = "{SERVICE_NAME}"
  command = ["sleep", "10000"],
  env = [
    "WEAVE_CIDR={CONTAINER_IP}/12",
    "CONTAINER_IP={CONTAINER_IP}",
    "CONTAINER_NAME={SERVICE_NAME}",
    "SERVICE_NAME={SERVICE_NAME}.clusterlite.local",
    "PUBLIC_HOST_IP={PUBLIC_HOST_IP}",
    "ZOOKEEPER_SERVICE_NAME=zookeeper.clusterlite.local",
    "KAFKA_HEAP_OPTS=-Xmx512M -Xms128M"
  ],
  restart = "always",
  hostname = "{SERVICE_NAME}.clusterlite.local",
  ports = [
      {
          internal = 80,
          external = 4444
      }
  ]
  destroy_grace_seconds = 30,
  volumes = [
      {
          host_path = "{VOLUME}/{SERVICE_NAME}",
          container_path = "/data",
          read_only = false
      }
  ]
  # remaining args:   -dti --init \ init can be worked around
}
