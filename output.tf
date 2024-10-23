output "aws-ec2-public-ip" {
  value = aws_instance.public-server.public_ip
}

output "aws-ec2-private-ip" {
  value = aws_instance.public-server.private_ip
}

output "gcp-vm-public-ip" {
  value = google_compute_address.vm.address
}

output "gcp-vm-private-ip" {
  value = google_compute_instance.vm.network_interface.0.network_ip

}