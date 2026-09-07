from airflow.decorators import dag, task
from datetime import datetime, timedelta
import boto3
import os
import vertica_python

# ============================================
# КОНФИГУРАЦИЯ
# ============================================

# S3 настройки
AWS_ACCESS_KEY_ID = "YCAJEiyNFq4wiOe_eMCMCXmQP"
AWS_SECRET_ACCESS_KEY = "YCP1e96y4QI8OmcB4Eaf4q0nMHwhmtvGbDTgBeqS"
BUCKET_NAME = 'sprint6'
LOCAL_PATH = '/data'

# Vertica настройки
VERTICA_CONFIG = {
    'host': 'vertica.data-engineer.education-services.ru',
    'port': 5433,
    'user': 'vt26082774b67b',
    'password': '9830a72a9dfa4caeb03263bf61fd44a8',
    'database': 'dwh',
    'autocommit': True
}
VERTICA_SCHEMA = 'VT26082774B67B__STAGING'

# ============================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================

def get_s3_client():
    """Создание S3 клиента"""
    session = boto3.session.Session()
    return session.client(
        service_name='s3',
        endpoint_url='https://storage.yandexcloud.net',
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    )

def load_table_to_vertica(table_name: str, file_name: str, columns: list):
    """
    Загрузка данных из CSV в Vertica через COPY
    """
    os.makedirs(LOCAL_PATH, exist_ok=True)
    
    # 1. Скачиваем файл из S3
    s3_client = get_s3_client()
    local_path = f'{LOCAL_PATH}/{file_name}'
    s3_client.download_file(BUCKET_NAME, file_name, local_path)
    print(f"✅ Downloaded: {file_name}")
    
    # 2. Загружаем в Vertica
    conn = vertica_python.connect(**VERTICA_CONFIG)
    cursor = conn.cursor()
    
    columns_str = ', '.join(columns)
    copy_sql = f"""
        COPY {VERTICA_SCHEMA}.{table_name} ({columns_str})
        FROM LOCAL '{local_path}'
        DELIMITER ','
        SKIP 1
        NULL ''
        ENCLOSED BY '"'
    """
    
    cursor.execute(copy_sql)
    print(f"✅ Loaded data into {VERTICA_SCHEMA}.{table_name}")
    
    # 3. Проверяем количество загруженных строк
    cursor.execute(f"SELECT COUNT(*) FROM {VERTICA_SCHEMA}.{table_name}")
    count = cursor.fetchone()[0]
    print(f"   Total rows in {table_name}: {count}")
    
    cursor.close()
    conn.close()
    
    # 4. Удаляем временный файл
    os.remove(local_path)
    print(f"🗑️  Removed: {local_path}")
    
    return count

# ============================================
# DAG В СТИЛЕ TASKFLOW API
# ============================================

@dag(
    schedule_interval=None,
    start_date=datetime(2022, 7, 13),
    catchup=False,
    description='Load data from S3 to Vertica staging layer (TaskFlow API)',
    tags=['sprint6', 'vertica', 'staging', 'taskflow'],
    default_args={
        'owner': 'airflow',
        'retries': 2,
        'retry_delay': timedelta(minutes=2),
    }
)
def sprint6_load_staging_taskflow():
    
    @task
    def load_dialogs():
        """Загрузка таблицы dialogs"""
        return load_table_to_vertica(
            table_name='dialogs',
            file_name='dialogs.csv',
            columns=['message_id', 'message_ts', 'message_from', 'message_to', 'message', 'message_group']
        )
    
    @task
    def load_users():
        """Загрузка таблицы users"""
        return load_table_to_vertica(
            table_name='users',
            file_name='users.csv',
            columns=['id', 'chat_name', 'registration_dt', 'country', 'age']
        )
    
    @task
    def load_groups():
        """Загрузка таблицы groups"""
        return load_table_to_vertica(
            table_name='groups',
            file_name='groups.csv',
            columns=['id', 'admin_id', 'group_name', 'registration_dt', 'is_private']
        )
    
    @task
    def verify_loading(dialogs_count: int, users_count: int, groups_count: int):
        """
        Проверка загрузки всех таблиц
        """
        conn = vertica_python.connect(**VERTICA_CONFIG)
        cursor = conn.cursor()
        
        print("\n" + "="*50)
        print("📊 VERIFICATION SUMMARY")
        print("="*50)
        
        results = {}
        for table in ['users', 'groups', 'dialogs']:
            cursor.execute(f"SELECT COUNT(*) FROM {VERTICA_SCHEMA}.{table}")
            count = cursor.fetchone()[0]
            results[table] = count
            print(f"   {table}: {count:>6} rows")
        
        print("="*50)
        print(f"   Total:  {sum(results.values()):>6} rows")
        print("="*50)
        
        cursor.close()
        conn.close()
        
        return results
    
    # ============================================
    # ОПРЕДЕЛЕНИЕ ЗАВИСИМОСТЕЙ
    # ============================================
    
    # Загрузка данных (выполняется параллельно)
    dialogs_count = load_dialogs()
    users_count = load_users()
    groups_count = load_groups()
    
    # Проверка после завершения всех загрузок
    verify_result = verify_loading(dialogs_count, users_count, groups_count)
    
    # Возвращаем результат (будет видно в логах)
    return verify_result

# ============================================
# СОЗДАНИЕ ЭКЗЕМПЛЯРА DAG
# ============================================

dag_instance = sprint6_load_staging_taskflow()