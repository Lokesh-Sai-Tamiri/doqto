variable "project_name" {
  type = string
}

variable "app_secrets" {
  type      = map(string)
  sensitive = true
}
