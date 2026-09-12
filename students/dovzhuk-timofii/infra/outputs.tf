output "instance_id" {
  description = "ID of the created EC2 instance"
  value       = aws_instance.nodeapp.id
}

output "instance_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.nodeapp.public_ip
}

output "application_url" {
  description = "URL of the Node.js application"
  value       = "http://${aws_instance.nodeapp.public_ip}:3000"
}

output "ssh_command" {
  description = "Example SSH command"
  value       = "ssh -i ${var.private_key_path} ubuntu@${aws_instance.nodeapp.public_ip}"
}

