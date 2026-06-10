
variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH key for VM metadata"
  type        = string
}
