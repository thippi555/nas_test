terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file) # 変数指定する場合
  project     = "thippistartp2023"
  region      = "asia-northeast1"
}

resource "google_storage_bucket" "demo" {
  name     = "demo-terraform-bucket-123456"
  location = "ASIA-NORTHEAST1"
}

# 関数コードを格納するバケット   kokokoko
resource "google_storage_bucket" "function_bucket" {
  name     = "function-code-bucket-${random_id.rand.hex}"
  location = var.region
}

# 関数コード(zip)をアップロード
resource "google_storage_bucket_object" "function_source" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "function.zip"
}

# Cloud Function本体
resource "google_cloudfunctions2_function" "sales_preprocess" {
  name     = "sales-preprocess-func"
  location = var.region

  build_config {
    runtime     = "python310"
    entry_point = "preprocess_file"
    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    available_memory   = "512M"
    environment_variables = {
      PROCESSED_BUCKET = google_storage_bucket.demo.name   # 既存のprocessedバケットに置き換える
      BQ_DATASET       = "sportsclub"
      BQ_SALES_TABLE   = "sales_report"
    }
  }

  event_trigger {
    event_type = "google.cloud.storage.object.v1.finalized"
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.demo.name          # rawバケットに置き換える
    }
  }
}

# ランダムID（バケット名ユニーク用）
resource "random_id" "rand" {
  byte_length = 4
}