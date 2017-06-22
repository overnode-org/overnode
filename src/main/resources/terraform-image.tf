resource "docker_image" "{IMAGE_NAME}-node-{NODE_ID}" {
  provider = "docker.node-{NODE_ID}"

  name = "{SERVICE_IMAGE}" # todo, deletion causes an error, because containers are being deleted at the same time
  # modification also causes hangs

  # see keep local params
  # see dynamic usage, which can trigger pull on change
}