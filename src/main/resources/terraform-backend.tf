terraform {
  backend "etcd" {
    path      = "terraform.tfstate"
    endpoints = "http://cade-etcd:2379"
  }
}
