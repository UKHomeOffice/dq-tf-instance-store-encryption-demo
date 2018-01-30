locals {
  instance_count = "2"
}

provider "aws" {
  region = "eu-west-2"
}


resource "aws_instance" "instance" {
  instance_type        = "d2.2xlarge"
  ami                  = "ami-c8d7c9ac"
  user_data            = <<EOF
#!/bin/bash

if [ ! -f /bin/aws ]; then
    curl https://bootstrap.pypa.io/get-pip.py | python
    pip install awscli
fi

if [ -b /dev/md0 ]; then
    aws --region eu-west-2 ssm get-parameter --name "instance_store_${count.index}" --with-decryption --query 'Parameter.Value' --output text | cryptsetup luksOpen /dev/md0 secure
else
    yum update -y
    yum install -y cryptsetup mdadm
    mdadm --create /dev/md0 --level=0 --raid-devices=6 /dev/xvdb /dev/xvdc /dev/xvdd /dev/xvde /dev/xvdf /dev/xvdg

    aws --region eu-west-2 ssm put-parameter --name "instance_store_${count.index}" --value "$(uuidgen)" --overwrite --type "SecureString"

    aws --region eu-west-2 ssm get-parameter --name "instance_store_${count.index}" --with-decryption --query 'Parameter.Value' --output text | cryptsetup -y --cipher=aes-cbc-essiv:sha256 luksFormat /dev/md0
    aws --region eu-west-2 ssm get-parameter --name "instance_store_${count.index}" --with-decryption --query 'Parameter.Value' --output text | cryptsetup luksOpen /dev/md0 secure
    mkfs.xfs /dev/mapper/secure
    mkdir /gpdb
fi
mount -o nodev,noatime,inode64,allocsize=16m /dev/mapper/secure /gpdb
EOF
  key_name             = "cns"
  count                = "${local.instance_count}"
  iam_instance_profile = "${element(aws_iam_instance_profile.instance_profile.*.id, count.index)}"
  tags {
    Name = "encryption demo ${count.index}"
  }
  ephemeral_block_device {
    virtual_name = "ephemeral0"
    device_name  = "/dev/sdb"
  }
  ephemeral_block_device {
    virtual_name = "ephemeral1"
    device_name  = "/dev/sdc"
  }
  ephemeral_block_device {
    virtual_name = "ephemeral2"
    device_name  = "/dev/sdd"
  }
  ephemeral_block_device {
    virtual_name = "ephemeral3"
    device_name  = "/dev/sde"
  }
  ephemeral_block_device {
    virtual_name = "ephemeral4"
    device_name  = "/dev/sdf"
  }
  ephemeral_block_device {
    virtual_name = "ephemeral5"
    device_name  = "/dev/sdg"
  }
  root_block_device {
    volume_type = "gp2"
    volume_size = 72
  }
  network_interface {
    device_index         = 0
    network_interface_id = "${element(aws_network_interface.interface_1.*.id, count.index)}"
  }
  network_interface {
    device_index         = 1
    network_interface_id = "${element(aws_network_interface.interface_2.*.id, count.index)}"
  }
  network_interface {
    device_index         = 2
    network_interface_id = "${element(aws_network_interface.interface_3.*.id, count.index)}"
  }
  network_interface {
    device_index         = 3
    network_interface_id = "${element(aws_network_interface.interface_4.*.id, count.index)}"
  }

}

output "instance-public" {
  value = "${aws_instance.instance.*.public_dns}"
}

resource "aws_network_interface" "interface_1" {
  subnet_id       = "${aws_subnet.subnets.0.id}"
  security_groups = [
    "sg-d080e9b8"
  ]
  count           = "${local.instance_count}"

  depends_on      = [
    "aws_subnet.subnets"]
}

resource "aws_network_interface" "interface_2" {
  subnet_id       = "${aws_subnet.subnets.1.id}"
  security_groups = [
    "sg-d080e9b8"
  ]
  depends_on      = [
    "aws_subnet.subnets"]
  count           = "${local.instance_count}"
}

resource "aws_network_interface" "interface_3" {
  subnet_id       = "${aws_subnet.subnets.2.id}"
  security_groups = [
    "sg-d080e9b8"
  ]
  depends_on      = [
    "aws_subnet.subnets"]
  count           = "${local.instance_count}"
}

resource "aws_network_interface" "interface_4" {
  subnet_id       = "${aws_subnet.subnets.3.id}"
  security_groups = [
    "sg-d080e9b8"
  ]
  depends_on      = [
    "aws_subnet.subnets"]
  count           = "${local.instance_count}"
}

resource "aws_eip" "eips" {
  vpc               = true
  network_interface = "${element(aws_network_interface.interface_1.*.id, count.index)}"
  count             = "${local.instance_count}"
}

resource "aws_subnet" "subnets" {
  vpc_id                  = "vpc-b1f2ccd8"
  cidr_block              = "10.1.${count.index + 35}.0/24"
  count                   = 4
  map_public_ip_on_launch = true
}


resource "aws_iam_role" "iam_role" {
  name_prefix        = "instance_store_encryption_demo"
  count              = "${local.instance_count}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = "instance_store_encryption_demo"
  role        = "${element(aws_iam_role.iam_role.*.name, count.index)}"
  count       = "${local.instance_count}"
}

resource "aws_iam_role_policy" "iam_role_policy" {
  name_prefix = "instance_store_encryption_demo"
  role        = "${element(aws_iam_role.iam_role.*.id, count.index)}"
  count       = "${local.instance_count}"

  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ssm:PutParameter",
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:eu-west-2:*:parameter/instance_store_${count.index}"
        }
    ]
}
EOF
}