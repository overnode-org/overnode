provider "docker" {
  alias = "{NODE_ID}"
  host = "http://{NODE_PROXY}:2375"
}
