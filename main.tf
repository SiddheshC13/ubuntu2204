provider "azurerm" {
  features {}
  subscription_id = "d630fcf5-f014-4de1-9128-09b8fc08fbea"
  client_id       = "fce4da25-0c67-4b9b-8e06-cac09f8feef4"
  client_secret   = "7qa8Q~fkvvCecU1XeCD1KRrWZovFeYa4Tw-e~bR5"
  tenant_id       = "00c05299-75fc-42de-9854-dd9d72df3efd"
}

terraform {
  backend "azurerm" {
    resource_group_name  = "storageforterraform"
    storage_account_name = "terraform01storage"
    container_name       = "terraform-storage"
    key                  = "terraform.tfstate"
  }
}

resource "azurerm_resource_group" "Resource-group" {
  name     = "Kubernetes-aks"
  location = "West Europe"
}

resource "azurerm_kubernetes_cluster" "azure-ks" {
  name                = "example-aks"
  location            = azurerm_resource_group.Resource-group.location
  resource_group_name = azurerm_resource_group.Resource-group.name
  dns_prefix          = "example"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.azure-ks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.azure-ks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.azure-ks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.azure-ks.kube_config.0.cluster_ca_certificate)
}

resource "kubernetes_deployment" "example" {
  metadata {
    name = "example-deployment"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        App = "App-Name"
      }
    }

    template {
      metadata {
        labels = {
          App = "App-Name"
        }
      }

      spec {
        container {
          image = "nginx:1.7.8"
          name  = "example"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "example" {
  metadata {
    name = "example-hpa"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.example.metadata[0].name
    }

    min_replicas = 1
    max_replicas = 10

    target_cpu_utilization_percentage = 50
  }
}