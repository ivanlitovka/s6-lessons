def check_csv_row_count():
    """Проверка количества строк в users.csv"""
    import csv
    import boto3
    
    s3_client = boto3.client(
        service_name='s3',
        endpoint_url='https://storage.yandexcloud.net',
        aws_access_key_id="YCAJEiyNFq4wiOe_eMCMCXmQP",
        aws_secret_access_key="YCP1e96y4QI8OmcB4Eaf4q0nMHwhmtvGbDTgBeqS",
    )
    
    # Скачиваем файл
    s3_client.download_file('sprint6', 'users.csv', '/data/users.csv')
    
    # Считаем строки
    with open('/data/users.csv', 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)  # Пропускаем заголовок
        count = 0
        for row in reader:
            count += 1
    
    print(f"Total rows in users.csv: {count}")
    return count

# Запустите это в отдельном скрипте или в Airflow
check_csv_row_count()