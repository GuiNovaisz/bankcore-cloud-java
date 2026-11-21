variable "name" {
  type = string
}
variable "region" {
  type = string
}
variable "account_id" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "public_subnets" {
  type = list(string)
}
variable "private_subnets" {
  type = list(string)
}
variable "alb_sg" {
  type = string
}
variable "service_sgs" {
  type = map(string)
}
variable "certificate_arn" {
  type = string
}
variable "services" {
  type = map(string)
}
variable "image_digests" {
  type = map(string)
}
variable "desired_count" {
  type = number
}
variable "db_host" {
  type = string
}
variable "db_master_secret" {
  type = string
}
variable "cache_host" {
  type = string
}
variable "queue_url" {
  type = string
}
variable "queue_arn" {
  type = string
}
variable "credentials" {
  type = map(string)
}

