terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "my-unique-tfstate-bucket"
    region = "ru-central1"
    key    = "terraform.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    use_path_style              = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = "ru-central1-a"
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# 1. Создаем сеть
resource "yandex_vpc_network" "network" {}

# 2. Создаем подсеть в этой сети
resource "yandex_vpc_subnet" "subnet" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

# 3. Резервируем постоянный статический IP
resource "yandex_vpc_address" "addr" {
  name = "static-ip-for-devops"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

# 4. Настраиваем файрвол (Группу безопасности)
resource "yandex_vpc_security_group" "vm-sg" {
  name        = "devops-server-sg"
  description = "Security group for web server"
  network_id  = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# 5. Создаем виртуалку и связываем всё вместе
resource "yandex_compute_instance" "vm" {
  name = "devops-server"
  
  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 30
    }
  }   

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    nat                = true # <--- ВКЛЮЧАЕМ РУЧНИК ПУБЛИЧНОГО IP (Это исправит ошибку)
    nat_ip_address     = yandex_vpc_address.addr.external_ipv4_address[0].address
    security_group_ids = [yandex_vpc_security_group.vm-sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

output "external_ip" {
  value = yandex_compute_instance.vm.network_interface.0.nat_ip_address
}