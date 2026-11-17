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
  default = ["156.207.215.236/32"]
}