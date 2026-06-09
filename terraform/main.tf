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

    access_key = "YCAJEgidefWgA7XzD6RiADoQ0"
    secret_key = "REMOVED_CLOUD_SECRET"

    # Полный набор заглушек для совместимости с Yandex Cloud
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    use_path_style              = true # Новый синтаксис вместо force_path_style

    # ВАЖНО: Отключаем проверку метаданных, которая вызывает 400 ошибку
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

# Подключаем провайдер Яндекса с авторизацией через JSON-файл
provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = "b1gcl65v9o8g9ikmsvmc" # Посмотри на главной странице консоли
  folder_id                = "b1gle25mltgv802km3fk" # Посмотри вверху экрана консоли
  zone                     = "ru-central1-a"
}
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}
# Создаем виртуальную сеть
resource "yandex_vpc_network" "network" {}

# Создаем подсеть
resource "yandex_vpc_subnet" "subnet" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

# Создаем виртуальную машину Ubuntu
resource "yandex_compute_instance" "vm" {
  name = "devops-server"
  
  resources {
    cores  = 2
    memory = 2 # 2 ГБ оперативной памяти хватит для Docker
  }

  boot_disk {
    initialize_params {
      # БЫЛО: image_id = "fd80bm0g9su9jsv38m6e"
      # СТАЛО:
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }   

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    nat                = true # Включаем публичный IP, чтобы подключаться из интернета
    security_group_ids = [yandex_vpc_security_group.vm-sg.id] # <-- ДОБАВИЛИ СВЯЗЬ С ГРУППОЙ БЕЗОПАСНОСТИ
  }

  metadata = {
    # Добавляем твой публичный SSH-ключ для доступа к серверу
    ssh-keys = "ubuntu:${file("id_ed25519.pub")}"
  }
}

# Выводим IP-адрес созданного сервера в терминал
output "external_ip" {
  value = yandex_compute_instance.vm.network_interface.0.nat_ip_address
}
resource "yandex_vpc_security_group" "vm-sg" {
  name        = "devops-server-sg"
  description = "Правила фильтрации трафика для нашего веб-сервера"
  network_id  = yandex_vpc_network.network.id

  # Разрешаем входящий SSH (порт 22) для управления
  ingress {
    protocol       = "TCP"
    description    = "Разрешить SSH"
    v4_cidr_blocks = ["0.0.0.0/0"] # В идеале здесь пишется твой личный IP, но для гибкости оставим весь мир
    port           = 22
  }

  # Разрешаем входящий HTTP (порт 80) для пользователей сайта
  ingress {
    protocol       = "TCP"
    description    = "Разрешить веб-трафик HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  # Разрешаем ВСЕГДА весь исходящий трафик (чтобы сервер мог качать обновления и образы Docker)
  egress {
    protocol       = "ANY"
    description    = "Разрешить весь исходящий трафик"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}