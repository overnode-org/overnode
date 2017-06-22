provider "docker" {
  alias = "node-{NODE_ID}"
  host = "http://{NODE_PROXY}:2375"
}