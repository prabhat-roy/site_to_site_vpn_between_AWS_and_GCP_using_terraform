resource "aws_instance" "public-server" {
  ami               = var.ami
  instance_type     = var.aws_instance_type
  subnet_id         = aws_subnet.public_subnet[0].id
  availability_zone = var.azs[0]
  security_groups   = ["${aws_security_group.sg.id}"]
  key_name          = var.kp
    root_block_device {
    volume_size = "20"
    volume_type = "gp3"
    delete_on_termination = true
  }
  tags = {
    Name = "AWS Server"
  }
}

resource "aws_security_group" "sg" {
  vpc_id      = aws_vpc.aws_vpc.id
  name        = "SSH"
  description = "Allow SSH Traffic"

  tags = {
    Name = "SSH Security Group"
  }
  ingress {

    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    #cidr_blocks = ["${format(jsondecode(data.http.ipinfo.body).ip)}/32"]
    cidr_blocks = ["${chomp(data.http.icanhazip.response_body)}/32"]
  }
  ingress {

    from_port = -1
    to_port   = -1
    protocol  = "icmp"

    cidr_blocks = [var.gcp_cidr[0]]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}