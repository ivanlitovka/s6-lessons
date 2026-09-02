import vertica_python

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

def try_select(conn_info=conn_info):
	# И рекомендуем использовать соединение вот так
    with vertica_python.connect(**conn_info) as conn:
        # do things
        # в конце этого блока соединение автоматически закроется.
        cur = conn.cursor()
        cur.execute("SELECT 1 as a1;")
        res = cur.fetchall()
    return res