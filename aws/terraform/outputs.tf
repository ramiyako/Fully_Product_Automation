output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.rf_automation.id
}

output "public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.rf_automation.public_ip
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "http://${aws_instance.rf_automation.public_ip}:8080"
}

output "kibana_url" {
  description = "Kibana URL"
  value       = "http://${aws_instance.rf_automation.public_ip}:5601"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.rf_automation.public_ip}"
}

output "jenkins_password_command" {
  description = "Command to get Jenkins initial password"
  value       = "ssh ubuntu@${aws_instance.rf_automation.public_ip} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'"
}
