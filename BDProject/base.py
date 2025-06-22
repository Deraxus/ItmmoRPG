import asyncpg
from telethon import TelegramClient
import asyncio
from datetime import datetime
from prettytable import PrettyTable

api_id = 26571368
api_hash = "16e182266e553e43ae816f43964dcc88"
api_token = "7928015612:AAElPJxfCn1TINzAVfQngR4b7wqDIlq5Gt4"


async def get_connection():
    """Подключение к PostgreSQL с подробным логгированием"""
    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] 🔄 Устанавливаем подключение к PostgreSQL...")
    try:
        conn = await asyncpg.connect(
            user='postgres',
            password='7828',
            database='itmmorpg',
            host='Localhost'
        )
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ✅ Успешное подключение к PostgreSQL!")
        return conn
    except Exception as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ❌ Ошибка подключения: {e}")
        raise


async def test_db_connection():
    """Тестирование подключения к БД с понятным выводом"""
    conn = await get_connection()
    try:
        # Получаем и красиво выводим информацию о БД
        db_version = await conn.fetchval("SELECT version()")
        test_result = await conn.fetchval("SELECT 1")

        print("\n📊 Информация о базе данных:")
        print(f"├─ Версия PostgreSQL: {db_version.split(',')[0]}")
        print(f"└─ Тестовый запрос: {test_result} (ожидалось: 1)")

    finally:
        await conn.close()
        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] 🔌 Подключение к БД закрыто")


async def run_bot():
    """Запуск Telegram бота с подробным логгированием"""
    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] 🤖 Запускаем Telegram бота...")
    client = TelegramClient('bot2026', api_id, api_hash)

    try:
        await client.start(bot_token=api_token)
        me = await client.get_me()
        print(f"[{datetime.now().strftime('%H:%M:%S')}] ✅ Бот успешно запущен!")
        print(f"    ├─ ID: {me.id}")
        print(f"    ├─ Имя: {me.first_name}")
        print(f"    └─ Username: @{me.username}")

        print("\n🔄 Бот работает и ожидает сообщений...")

        conn = await get_connection()

        db_name = await conn.fetchval("SELECT current_database()")
        print(f"Бот подключён к БД: {db_name}")

        tables = await conn.fetch("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        print("Существующие таблицы:", [t['table_name'] for t in tables])

        rows = await conn.fetch(f"SELECT * FROM server")
        print(rows)
        await client.run_until_disconnected()
    finally:
        print(123)


async def main():
    """Главная асинхронная функция"""
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 🚀 Начало работы программы")
    await test_db_connection()
    await run_bot()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] 🛑 Программа остановлена пользователем")
    except Exception as e:
        print(f"\n[{datetime.now().strftime('%H:%M:%S')}] 💥 Критическая ошибка: {e}")