# modules/ecr/variables.tf

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
