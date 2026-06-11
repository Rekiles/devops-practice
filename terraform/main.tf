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

resource "yandex_vpc_network" "network" {}

resource "yandex_vpc_subnet" "subnet" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

# === СТАТИЧЕСКИЙ IP-АДРЕС (Теперь он стоит отдельно на верхнем уровне) ===
resource "yandex_vpc_address" "addr" {
  name = "static-ip-for-devops"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}

# === ВИРТУАЛЬНАЯ МАШИНА ===
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
    nat_ip_address     = yandex_vpc_address.addr.external_ipv4_address[0].address
    security_group_ids = [yandex_vpc_security_group.vm-sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

resource "yandex_vpc_security_group" "vm-sg" {
  name       = "vm-security-group"
  network_id = yandex_vpc_network.your_network.id # подставь имя своей сети

  # Разрешаем SSH для настройки
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Разрешаем HTTP для работы приложения
  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Разрешаем серверу выходить в интернет (скачивать Docker, обновления)
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

output "external_ip" {
  value = yandex_compute_instance.vm.network_interface.0.nat_ip_address
}