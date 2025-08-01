output "frontend_public_dns" {
  description = "Public DNS of the Frontend instance"
  value       = aws_instance.frontend_instance.public_dns
}

output "frontend_public_ip" {
  description = "Public IP of the Frontend instance"
  value       = aws_instance.frontend_instance.public_ip
}

output "frontend_app_address" {
  description = "Address to access the frontend application"
  value       = "http://${aws_instance.frontend_instance.public_ip}:80"
}

