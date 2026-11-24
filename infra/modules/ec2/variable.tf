variable "vpc_cidr" {
  type    = string
 
}

variable "subnet_cidr" {
  type    = list(string)
 
}

variable "sg-name" {
  type    = string
 
}

variable "my_ip" {
  type    = list(string)
  
}
variable "runner_ip" {
  description = "Runner public IP(s) in CIDR form"
  type        = list(string)
}