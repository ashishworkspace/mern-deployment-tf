variable "github_repo_url" {
  description = "Enter the github endpoint"
  default     = "https://github.com/jalantechnologies/boilerplate-mern.git"
}


variable "project_dir" {
  description = "Project path directory"
  default     = "boilerplate-mern"
}

variable "image_name" {
  description = "Name of image being created"
  default     = "mern"
}

variable "k8s_config_path" {
  description = "Path of kube config file"
  default     = "C:\\Users\\getma\\.kube\\config"
}

variable "mongodb_url" {
  description = "Endpoint of mongodb"
  default     = "mongodb://root:password@mongodb-svc:27017"
}
