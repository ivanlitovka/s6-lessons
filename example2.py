import vertica_python
from getpass import getpass
import csv
from pathlib import Path

conn_info = {'host': 'vertica.data-engineer.education-services.ru', # Адрес сервера из инструкции
             'port': 5433,
             'user': 'vt26082774b67b',       # Полученный логин
             'password': '9830a72a9dfa4caeb03263bf61fd44a8',# пароль. 
                         # Если не любите хардкод, воспользуйтесь getpass()
                         # 'password': getpass(),
             'database': 'dwh',
             # Вначале он нам понадобится, а дальше — решите позже сами
             'autocommit': True
}

# И рекомендуем использовать соединение вот так
# with vertica_python.connect(**conn_info) as conn:
#     # do things
#     # в конце этого блока соединение автоматически закроется.
#         cur = conn.cursor()
#         cur.execute("SELECT 1 as a1;")
#         res = cur.fetchall()
#         print(res)

dataset = 'test_dataset.csv'
N = 10000 # на этот раз можете поставить даже 10 млн

with open(dataset, 'w') as csvfile:
    fwriter = csv.writer(csvfile, delimiter='|')
    for i in range(N):
        fwriter.writerow([i, 'asds'])

# эта команда напечатает абсолютный путь к файлу, скопируйте его
print(Path(dataset).resolve())

# а это пара первых строк для визуализации результата:
with open(dataset, 'r') as csvfile:
    for i in range(5):
        print(csvfile.readline(), end='') 