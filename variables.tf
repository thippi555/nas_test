variable "credentials_file" {
  description = "Path to the service account JSON key"
  default     = "~/thippistartp2023-fc109068fd59.json" # ここは $HOME/key.json に変えてOK
}

variable "project_id" {
  description = "GCP Project ID"
  default     = "thippistartp2023"
}

variable "region" {
  description = "GCP Region"
  default     = "asia-northeast1"
}