terraform {
  backend "etcd" {
    path      = "terraform.tfstate"
    endpoints = "http://clusterlite-etcd:2379"
  }
}