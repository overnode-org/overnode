data "terraform_remote_state" "etcd" {
  backend = "etcd"
  config {
    path      = "terraform.tfstate"
    endpoints = "http://clusterlite-etcd:2379"
  }
}
