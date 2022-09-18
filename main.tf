########################################################################

# cloneing repo => Will run once
resource "null_resource" "git_clone" {
  provisioner "local-exec" {
    command = "git clone ${var.github_repo_url}"
  }
}


# pull the latest code from repo => Will run on every terrform apply
resource "null_resource" "git_pull" {
  depends_on = [
    null_resource.git_clone
  ]
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "cd ${var.project_dir} && git pull"
  }
}

# grabing latest commit id => help in building image with different tags
data "external" "git_hash" {
  depends_on = [
    null_resource.git_pull
  ]
  program = ["sh", "-c", <<-EOSCRIPT
    jq -n '{ "git_hash": $REV }' \
    --arg REV "$(cd ${var.project_dir} && git rev-parse --short HEAD)"
  EOSCRIPT
  ]
}
locals {
  git = data.external.git_hash.result
}



# build the image out of latest code => Will run on every terraform apply
resource "null_resource" "docker_build" {
  depends_on = [
    data.external.git_hash
  ]
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "docker build -t ${var.image_name}:${local.git.git_hash} --rm ${var.project_dir}/"
  }
}

########################################################################

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.13.1"
    }
  }
}

provider "kubernetes" {
  # Configuration options
  config_path = var.k8s_config_path
}

# Mongodb application => listening on port 27017
resource "kubernetes_deployment" "mongodb-deployment" {
  depends_on = [
    null_resource.docker_build
  ]
  metadata {
    name = "mongodb"
    labels = {
      app = "mongodb"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongodb"
        }
      }

      spec {
        container {
          image = "mongo:latest"
          name  = "mongodb"
          port {
            container_port = 27017
          }
          env {
            name  = "MONGO_INITDB_ROOT_USERNAME"
            value = "root"
          }
          env {
            name  = "MONGO_INITDB_ROOT_PASSWORD"
            value = "password"
          }
        }
      }
    }
  }
}



# Mern applicaion => Listening on nodeport => Minikube ip:nodeport
resource "kubernetes_service" "mognodb-svc" {
  metadata {
    name = "mongodb-svc"
  }
  spec {
    selector = {
      app = kubernetes_deployment.mongodb-deployment.metadata.0.labels.app
    }
    port {
      port        = 27017
      target_port = 27017
    }

    type = "ClusterIP"
  }
}


resource "kubernetes_deployment" "mern-app-deployment" {
  depends_on = [
    kubernetes_deployment.mongodb-deployment
  ]
  metadata {
    name = "mern-application"
    labels = {
      app = "mern"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "mern"
      }
    }

    template {
      metadata {
        labels = {
          app = "mern"
        }
      }

      spec {
        container {
          image = "${var.image_name}:${local.git.git_hash}"
          name  = "mern"
          port {
            container_port = 8080
          }
          env {
            name  = "MONGODB_URI"
            value = "${var.app_config}"
          }
          # resources {
          #   limits = {
          #     cpu    = "0.5"
          #     memory = "512Mi"
          #   }
          #   requests = {
          #     cpu    = "0.5"
          #     memory = "512Mi"
          #   }
          # }
        }
      }
    }
  }
}

resource "kubernetes_service" "mern-app-svc" {
  metadata {
    name = "mern-application-svc"
  }
  spec {
    selector = {
      app = kubernetes_deployment.mern-app-deployment.metadata.0.labels.app
    }
    port {
      port        = 8080
      target_port = 8080
    }

    type = "NodePort"
  }
}
