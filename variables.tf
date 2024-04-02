variable "do_token" {
  description = "DO API token"
  type = string
  sensitive = true
}

variable "db_user" {
  type = string
  sensitive = true
}

variable "db_name" {
  type = string
  sensitive = true
}

