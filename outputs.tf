output "ec2-public_ip" {
  value = module.myapp-server.instance_info.public_ip
}
