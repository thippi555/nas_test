from google.cloud import storage, bigquery
import os
import pandas as pd
import io
import traceback

def preprocess_file(event, context):
    file_name = event['name']
    raw_bucket = event['bucket']
    processed_bucket = os.environ.get("PROCESSED_BUCKET")
    dataset_id = os.environ.get("BQ_DATASET")
    table_id = os.environ.get("BQ_SALES_TABLE")

    storage_client = storage.Client()
    bq_client = bigquery.Client()

    try:
        # === 1. raw-bucketからファイル取得 ===
        raw_blob = storage_client.bucket(raw_bucket).blob(file_name)
        raw_data = raw_blob.download_as_bytes()

        # === 2. DataFrameに変換 + 前処理 ===
        df = pd.read_csv(io.BytesIO(raw_data), encoding="utf-8", dtype=str)
        df.fillna({
            "NO": "0",
            "UriageDate": "1970-01-01",
            "Store": "不明",
            "Kamoku": "0",
            "HojoKamoku": "0",
            "Suryo": "0",
            "Kingaku": "0",
            "Shouhizei": "0",
            "Tekiyou": "未設定"
        }, inplace=True)

        # === 3. processed-bucket に保存 ===
        output = io.StringIO()
        df.to_csv(output, index=False, encoding="utf-8")
        processed_blob = storage_client.bucket(processed_bucket).blob(file_name)
        processed_blob.upload_from_string(output.getvalue(), content_type="text/csv")
        print(f"[SUCCESS] {file_name} → {processed_bucket}")

        # === 4. BigQuery にロード ===
        table_ref = f"{bq_client.project}.{dataset_id}.{table_id}"
        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.CSV,
            skip_leading_rows=1,
            autodetect=False,
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        )

        load_job = bq_client.load_table_from_dataframe(df, table_ref, job_config=job_config)
        load_job.result()
        print(f"[SUCCESS] {file_name} を BigQuery({table_ref}) にロード完了")

    except Exception as e:
        print(f"[ERROR] {file_name}: {e}")
        traceback.print_exc()
