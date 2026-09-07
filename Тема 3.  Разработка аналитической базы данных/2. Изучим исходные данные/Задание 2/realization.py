from airflow.decorators import dag, task
from airflow.operators.bash import BashOperator
import pendulum
import boto3
import os

# Конфигурация
AWS_ACCESS_KEY_ID = "YCAJEiyNFq4wiOe_eMCMCXmQP"
AWS_SECRET_ACCESS_KEY = "YCP1e96y4QI8OmcB4Eaf4q0nMHwhmtvGbDTgBeqS"
BUCKET_NAME = 'sprint6'
LOCAL_PATH = '/data'
FILES = ['groups.csv', 'users.csv', 'dialogs.csv']

def get_s3_client():
    """Создание S3 клиента"""
    session = boto3.session.Session()
    return session.client(
        service_name='s3',
        endpoint_url='https://storage.yandexcloud.net',
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    )

@dag(
    schedule_interval=None,
    start_date=pendulum.parse('2022-07-13'),
    catchup=False,
    description='Download files from Yandex Cloud S3'
)
def sprint6_dag_get_data_taskflow():
    
    @task
    def setup_directory():
        """Создание директории для загрузки"""
        os.makedirs(LOCAL_PATH, exist_ok=True)
        return f"Directory {LOCAL_PATH} ready"
    
    @task
    def download_file(file_name: str):
        """Скачивание одного файла из S3"""
        s3_client = get_s3_client()
        local_path = f'{LOCAL_PATH}/{file_name}'
        
        try:
            s3_client.download_file(
                Bucket=BUCKET_NAME,
                Key=file_name,
                Filename=local_path
            )
            
            if os.path.exists(local_path):
                file_size = os.path.getsize(local_path)
                return f"Downloaded {file_name} ({file_size} bytes)"
            else:
                raise Exception(f"File {file_name} not found after download")
                
        except Exception as e:
            raise Exception(f"Failed to download {file_name}: {e}")
    
    @task
    def verify_and_print_files():
        """Проверка и вывод первых 10 строк всех файлов"""
        results = []
        
        for file_name in FILES:
            file_path = f'{LOCAL_PATH}/{file_name}'
            
            if not os.path.exists(file_path):
                results.append(f"File {file_name} not found!")
                continue
            
            with open(file_path, 'r') as f:
                lines = f.readlines()[:10]
                results.append(f"=== First 10 lines of {file_name} ===")
                results.extend([line.strip() for line in lines])
                results.append("")
        
        return "\n".join(results)
    
    # Определение зависимостей
    setup = setup_directory()
    
    # Скачиваем все файлы параллельно
    download_tasks = []
    for file_name in FILES:
        download_task = download_file(file_name)
        download_tasks.append(download_task)
        setup >> download_task
    
    # Задача проверки выполняется после всех скачиваний
    verify_task = verify_and_print_files()
    for download_task in download_tasks:
        download_task >> verify_task

dag_instance = sprint6_dag_get_data_taskflow()