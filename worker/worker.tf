variable "security_group_id" {}
variable "key_name" {
  default = "abhaya-aws"
}
variable "ami" {
  default = "ami-42934921"
}
variable "name" {}
variable "ip_one" {}
variable "ip_two" {}
variable "ip_three" {}
variable "subnet_id" {}
variable "ip" {}
variable "base_dir" {
  default = "/opt/hashi"
}
variable "data_dir" {
  default = "/opt/hashi/data"
}
variable "config_dir" {
  default = "/opt/hashi/config"
}
variable "bin_dir" {
  default = "/opt/hashi/bin"
}
variable "pid_dir" {
  default = "/opt/hashi/pid"
}
variable "systemd_dir" {
  default = "/etc/systemd/system"
}
variable "nomad_type" {
  default = "client"
}

data "template_file" "nomad_base_hcl" {
  template = "${file("templates/nomad_base.hcl.tpl")}"
  vars {
    data_dir   = "${var.data_dir}"
    ip         = "${var.ip}"
  }
}

data "template_file" "nomad_client_hcl" {
  template = "${file("templates/nomad_client.hcl.tpl")}"
  vars {
    ip_one   = "${var.ip_one}"
    ip_two   = "${var.ip_two}"
    ip_three = "${var.ip_three}"
  }
}

data "template_file" "nomad_service" {
  template = "${file("templates/nomad.service.tpl")}"
  vars {
    data_dir   = "${var.data_dir}"
    config_dir = "${var.config_dir}"
    bin_dir    = "${var.bin_dir}"
    nomad_type = "${var.nomad_type}"
  }
}

data "template_file" "provisioner" {
  template = "${file("templates/provision.sh.tpl")}"
  vars {
    bin_dir    = "${var.bin_dir}"
  }
}

data "template_file" "consul_service" {
  template = "${file("templates/consul.service.tpl")}"
  vars {
    data_dir   = "${var.data_dir}"
    config_dir = "${var.config_dir}"
    bin_dir    = "${var.bin_dir}"
    pid_dir    = "${var.pid_dir}"
  }
}

data "template_file" "consul_json" {
  template = "${file("templates/consul_client.json.tpl")}"
  vars {
    name       = "${var.name}"
    config_dir = "${var.config_dir}"
    data_dir   = "${var.data_dir}"
    ip_other_1 = "${var.ip_one}"
    ip_other_2 = "${var.ip_two}"
  }
}

resource "aws_instance" "instance" {
  ami                         = "${var.ami}"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = ["${var.security_group_id}"]
  subnet_id                   = "${var.subnet_id}"
  key_name                    = "${var.key_name}"
  private_ip                  = "${var.ip}"
  associate_public_ip_address = true

  provisioner "remote-exec" {
    connection = {
      user = "ubuntu"
      private_key = "${file("abhaya-aws.pem")}"
    }
    inline = [
      "sudo mkdir -p ${var.data_dir}/consul",
      "sudo mkdir -p ${var.data_dir}/nomad",
      "sudo mkdir -p ${var.config_dir}/consul",
      "sudo mkdir -p ${var.config_dir}/nomad",
      "sudo mkdir -p ${var.bin_dir}",
      "sudo mkdir -p ${var.pid_dir}",
      "sudo chown -R ubuntu.ubuntu ${var.base_dir}"
    ]
  }

  provisioner "file" {
    connection = {
      user = "ubuntu"
      private_key = "${file("abhaya-aws.pem")}"
    }
    content = "${data.template_file.nomad_base_hcl.rendered}"
    destination = "${var.config_dir}/nomad/base.hcl"
  }

  provisioner "file" {
    connection = {
      user = "ubuntu"
      private_key = "${file("abhaya-aws.pem")}"
    }
    content = "${data.template_file.nomad_client_hcl.rendered}"
    destination = "${var.config_dir}/nomad/client.hcl"
  }

  provisioner "file" {
    connection = {
      user = "ubuntu"
      private_key = "${file("abhaya-aws.pem")}"
    }
    content = "${data.template_file.nomad_service.rendered}"
    destination = "/tmp/nomad.service"
  }

  provisioner "file" {
    connection = {
      user = "ubuntu"
      private_key = "${file("abhaya-aws.pem")}"
    }
    content = "${data.template_file.provisioner.rendered}"
    destination = "/tmp/provision.sh"
  }

  provisioner "file" {
    connection = {
      user = "ubuntu"
      private_key = "${file("abhaya-aws.pem")}"
    }
    content = "${data.template_file.consul_service.rendered}"
    destination = "/tmp/consul.service"
  }

  provisioner "file" {
    connection = {
      user = "ubuntu"
      private_key = "${file("abhaya-aws.pem")}"
    }
    content = "${data.template_file.consul_json.rendered}"
    destination = "${var.config_dir}/consul.json"
  }

  provisioner "remote-exec" {
    connection = {
      user = "ubuntu"
      private_key = "${file("abhaya-aws.pem")}"
    }
    inline = [
      "sudo chown -R root.root /opt/hashi",
      "sudo mv /tmp/*.service ${var.systemd_dir}"
    ]
  }

  provisioner "remote-exec" {
    connection = {
      user = "ubuntu"
      private_key = "${file("abhaya-aws.pem")}"
    }
    inline = [
      "sudo chmod a+x /tmp/provision.sh",
      "sudo /tmp/provision.sh"
    ]
  }
}

output "private_ip" {
  value = "${aws_instance.instance.private_ip}"
}
