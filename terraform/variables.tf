variable "access_key" {
  description = "Yandex Cloud access key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Yandex Cloud secret key"
  type        = string
  sensitive   = true
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}
