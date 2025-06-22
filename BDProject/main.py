# mmo_bot_charbuttons_fixed.py
from telethon import TelegramClient, events
from telethon.tl.types import ReplyInlineMarkup, KeyboardButtonRow, KeyboardButtonCallback
import asyncpg, asyncio, datetime as dt

# ───── настройки ─────────────────────────────────────────────
api_id, api_hash = 26571368, "16e182266e553e43ae816f43964dcc88"
bot_token        = "7928015612:AAElPJxfCn1TINzAVfQngR4b7wqDIlq5Gt4"
pg_user, pg_pass, pg_db, pg_host = "postgres", "7828", "itmmorpg", "localhost"
# ──────────────────────────────────────────────────────────────

client                       = TelegramClient("mmobot", api_id, api_hash)
db: asyncpg.Connection

# контексты и буферы
sess_game, sess_stat = {}, {}
ask_create, ask_delete, tmp_name, ask_char = set(), set(), {}, set()

def row(*btns): return KeyboardButtonRow(list(btns))    # удобный алиас
BACK_MAIN = ReplyInlineMarkup([row(KeyboardButtonCallback("⬅ Меню", b"menu"))])

# ───── ВСПОМОГАТЕЛЬНЫЕ ───────────────────────────────────────
async def pg_connect():
    print(f"[{dt.datetime.now():%H:%M:%S}] ↻  PostgreSQL…")
    c = await asyncpg.connect(user=pg_user, password=pg_pass, database=pg_db, host=pg_host)
    print("✅ PG готов"); return c

async def main_menu(uid:int):
    await client.send_message(
        uid, "Главное меню:",
        buttons=ReplyInlineMarkup([
            row(KeyboardButtonCallback("🎮 Играть",      b"play")),
            row(KeyboardButtonCallback("📊 Статистика",  b"stat_srv"))
        ])
    )

def stat_sid(uid:int): return sess_stat.get(uid)

def back_to_categories(uid:int)->ReplyInlineMarkup:
    sid = stat_sid(uid)
    return ReplyInlineMarkup([row(KeyboardButtonCallback("⬅ Категории", f"st_{sid}".encode()))])

# ───── базовые команды ───────────────────────────────────────
@client.on(events.NewMessage(pattern="/start"))
async def _(e): await main_menu(e.chat_id)
@client.on(events.CallbackQuery(data=b"menu"))
async def _(e): await main_menu(e.chat_id)

# ───── Ⅰ. «ИГРАТЬ» ───────────────────────────────────────────
@client.on(events.CallbackQuery(data=b"play"))
async def play_choose_server(e):
    rows=await db.fetch("SELECT server_id,server_name FROM server")
    if not rows:
        return await e.respond("❌ Нет серверов.", buttons=BACK_MAIN)
    kb=[row(KeyboardButtonCallback(r["server_name"], f"play_srv_{r['server_id']}".encode())) for r in rows]
    kb.append(row(KeyboardButtonCallback("⬅ Меню", b"menu")))
    await e.respond("🌐 Выберите сервер:", buttons=ReplyInlineMarkup(kb))

@client.on(events.CallbackQuery(data=lambda d:d.startswith(b"play_srv_")))
async def play_menu(e):
    uid, sid = e.sender_id, int(e.data.decode().split("_")[-1])
    sess_game[uid] = sid
    await e.respond(f"Сервер #{sid} выбран.",
        buttons=ReplyInlineMarkup([
            row(KeyboardButtonCallback("👥 Все персонажи", b"pl_list")),
            row(KeyboardButtonCallback("➕ Создать", b"pl_add"),
                KeyboardButtonCallback("🗑 Удалить", b"pl_del")),
            row(KeyboardButtonCallback("🆕 Локация",  b"loc_add"),
                KeyboardButtonCallback("🐲 Моб",      b"mob_add")),
            row(KeyboardButtonCallback("⬅ Серверы", b"play"))
        ]))


@client.on(events.CallbackQuery(data=b"pl_list"))
async def pl_list(e):
    sid=sess_game.get(e.sender_id)
    if not sid:
        return await e.respond("⚠ Выберите сервер.", buttons=BACK_MAIN)
    rows=await db.fetch("SELECT character_name,level FROM player_character WHERE server_id=$1",sid)
    txt="\n".join(f"{r['character_name']} — {r['level']} ур." for r in rows) or "нет персонажей"
    await e.respond(f"👥:\n{txt}", buttons=BACK_MAIN)

@client.on(events.CallbackQuery(data=b"pl_add"))
async def pl_add(e): ask_create.add(e.sender_id); await e.respond("Имя нового персонажа:")

@client.on(events.CallbackQuery(data=b"pl_del"))
async def pl_del(e): ask_delete.add(e.sender_id); await e.respond("Имя персонажа для удаления:")

@client.on(events.NewMessage)
async def on_text(e):
    uid = e.sender_id; txt = e.raw_text.strip()

    # создание
    if uid in ask_create:
        tmp_name[uid] = txt; ask_create.remove(uid)
        classes=await db.fetch("SELECT class_id,class_name FROM character_class")
        kb=[row(KeyboardButtonCallback(r["class_name"], f"pick_{r['class_id']}".encode())) for r in classes]
        return await client.send_message(uid,"Выберите класс:",buttons=ReplyInlineMarkup(kb))

    # удаление
    if uid in ask_delete:
        ask_delete.remove(uid); sid=sess_game.get(uid)
        await db.execute("DELETE FROM player_character WHERE character_name=$1 AND server_id=$2",txt,sid)
        return await client.send_message(uid,f"🗑 {txt} удалён (если был).",buttons=BACK_MAIN)

        # создание моба
    if uid in ask_mob_step:
        st = ask_mob_step[uid]["step"]
        dat = ask_mob_step[uid]["data"]

        if st == 0:
            dat["name"] = txt
            ask_mob_step[uid]["step"] = 1
            return await e.respond("Уровень моба (целое число ≥ 1):")

        # step 1 – уровень
        if st == 1:
            if not txt.isdigit() or int(txt) < 1:
                return await e.respond("Введите корректный уровень.")
            dat["level"] = int(txt)
            ask_mob_step[uid]["step"] = 2
            return await e.respond("Здоровье (HP):")

        # step 2 – HP
        if st == 2:
            if not txt.isdigit() or int(txt) < 1:
                return await e.respond("Введите положительное число HP.")
            dat["hp"] = int(txt)
            ask_mob_step[uid]["step"] = 3
            return await e.respond("Атака (ATK):")

        # step 3 – ATK и финальная вставка
        if st == 3:
            if not txt.isdigit() or int(txt) < 0:
                return await e.respond("Введите число ATK.")
            dat["atk"] = int(txt)

            await db.execute("""
                INSERT INTO mob (location_id, mob_name, level, health, attack_power)
                VALUES ($1, $2, $3, $4, $5)
            """, dat["loc_id"], dat["name"], dat["level"],
                             dat["hp"], dat["atk"])

            ask_mob_step.pop(uid, None)
            return await e.respond(f"✅ Моб «{dat['name']}» создан.", buttons=BACK_MAIN)

@client.on(events.CallbackQuery(data=lambda d:d.startswith(b"pick_")))
async def picked_class(e):
    uid=e.sender_id; cls=int(e.data.decode().split("_")[-1])
    sid=sess_game.get(uid); name=tmp_name.pop(uid,"Noname")
    await db.execute("""
      INSERT INTO player_character(server_id,class_id,location_id,character_name,is_moderator)
      VALUES($1,$2,1,$3,false)""",sid,cls,name)
    await e.respond(f"✅ Создан {name}.", buttons=BACK_MAIN)

# ───── Ⅱ. «СТАТИСТИКА» ───────────────────────────────────────
@client.on(events.CallbackQuery(data=b"stat_srv"))
async def stat_choose_srv(e):
    rows=await db.fetch("SELECT server_id,server_name FROM server")
    kb=[row(KeyboardButtonCallback(r["server_name"], f"st_{r['server_id']}".encode())) for r in rows]
    kb.append(row(KeyboardButtonCallback("⬅ Меню", b"menu")))
    await e.respond("📊 Сервер:", buttons=ReplyInlineMarkup(kb))

@client.on(events.CallbackQuery(data=lambda d:d.startswith(b"st_") and d!=b"stat_srv"))
async def stat_categories(e):
    uid = e.sender_id
    sid = int(e.data.decode().split("_")[-1])
    sess_stat[uid] = sid

    await e.respond(f"Сервер #{sid}. Категории:",
        buttons=ReplyInlineMarkup([
            row(KeyboardButtonCallback("ℹ️ Персонажи",      b"s0")),
            row(KeyboardButtonCallback("🎒 Инвентарь",       b"s1"),
                KeyboardButtonCallback("🏆 Топ-3",            b"s2")),
            row(KeyboardButtonCallback("🌍 Локации",         b"s4"),
                KeyboardButtonCallback("🏰 Подземелья",       b"s9")),
            row(KeyboardButtonCallback("📊 Рейтинг",         b"s5"),
                KeyboardButtonCallback("👹 Боссы",            b"s6")),
            row(KeyboardButtonCallback("⚙ Начислить опыт всем игрокам",             b"s7")),
            row(KeyboardButtonCallback("⬅ Серверы",          b"stat_srv"))
        ]))


# Список персонажей кнопками
@client.on(events.CallbackQuery(data=b"s0"))
async def stat_char_buttons(e):
    sid=stat_sid(e.sender_id)
    if not sid: return await e.respond("Выберите сервер.",buttons=BACK_MAIN)
    rows=await db.fetch("SELECT character_id,character_name FROM player_character WHERE server_id=$1",sid)
    if not rows: return await e.respond("На сервере нет персонажей.",buttons=back_to_categories(e.sender_id))
    kb=[row(KeyboardButtonCallback(r["character_name"], f"ci_{r['character_id']}".encode())) for r in rows]
    kb.append(row(KeyboardButtonCallback("⬅ Категории", f"st_{sid}".encode())))
    await e.respond("Персонажи:", buttons=ReplyInlineMarkup(kb))

# карточка персонажа
@client.on(events.CallbackQuery(data=lambda d:d.startswith(b"ci_")))
async def stat_char_card(e):
    char_id=int(e.data.decode().split("_")[-1]); sid=stat_sid(e.sender_id)
    row=await db.fetchrow("""
      SELECT p.character_name,p.level,p.experience,p.is_moderator,
             cc.class_name,l.location_name
      FROM player_character p
      JOIN character_class cc USING(class_id)
      JOIN location l USING(location_id)
      WHERE p.character_id=$1 AND p.server_id=$2""",char_id,sid)
    if not row:
        return await e.respond("Не найден.",buttons=back_to_categories(e.sender_id))
    txt=(f"ℹ️ {row['character_name']}\n"
         f"• Уровень:   {row['level']}\n"
         f"• Опыт:      {row['experience']}\n"
         f"• Класс:     {row['class_name']}\n"
         f"• Локация:   {row['location_name']}\n"
         f"• Модератор: {'да' if row['is_moderator'] else 'нет'}")
    await e.respond(txt, buttons=back_to_categories(e.sender_id))

# ─── стат-пункты s1–s8───────────
async def stat_ans(e,txt): await e.respond(txt, buttons=back_to_categories(e.sender_id))

@client.on(events.CallbackQuery(data=b"s1"))
async def s1(e):
    sid=stat_sid(e.sender_id)
    if not sid: return await stat_ans(e,"Выберите сервер")
    rows=await db.fetch("""
      SELECT c.character_name,COUNT(pi.item_id) cnt
      FROM player_character c LEFT JOIN player_item pi USING(character_id)
      WHERE c.server_id=$1 GROUP BY c.character_name""",sid)
    txt="\n".join(f"{r['character_name']}: {r['cnt']}" for r in rows) or "пусто"
    await stat_ans(e,f"🎒 Инвентарь:\n{txt}")

@client.on(events.CallbackQuery(data=b"s2"))
async def s2(e):
    sid=stat_sid(e.sender_id)
    if not sid: return await stat_ans(e,"Выберите сервер")
    rows=await db.fetch("""
      SELECT character_name,level
      FROM player_character WHERE server_id=$1
      ORDER BY level DESC LIMIT 3""",sid)
    txt="\n".join(f"{r['character_name']} — {r['level']} ур." for r in rows) or "нет"
    await stat_ans(e,f"🏆 Топ-3:\n{txt}")

@client.on(events.CallbackQuery(data=b"s4"))
async def s4(e):
    sid=stat_sid(e.sender_id)
    if not sid: return await stat_ans(e,"Выберите сервер")
    rows = await db.fetch("""
        SELECT l.location_name,
               COALESCE(COUNT(m.mob_id), 0) AS mc
        FROM   location l
        LEFT   JOIN mob m ON m.location_id = l.location_id
        WHERE  l.server_id = $1          -- placeholder для sid
        GROUP  BY l.location_name
        ORDER  BY mc DESC;
    """, sid)
    txt="\n".join(f"{r['location_name']} — {r['mc']} mob" for r in rows) or "нет"
    await stat_ans(e,f"🌍 Локации>\n{txt}")

@client.on(events.CallbackQuery(data=b"s5"))
async def s5(e):
    sid=stat_sid(e.sender_id)
    if not sid: return await stat_ans(e,"Выберите сервер")
    rows=await db.fetch("""
      SELECT character_name,level,
             RANK()OVER(ORDER BY level DESC) rk
      FROM player_character WHERE server_id=$1""",sid)
    txt="\n".join(f"{r['rk']}. {r['character_name']} — {r['level']} ур." for r in rows)
    await stat_ans(e,f"📊 Рейтинг:\n{txt}")

@client.on(events.CallbackQuery(data=b"s6"))
async def s6(e):
    sid = stat_sid(e.sender_id)
    if not sid:
        return await stat_ans(e, "Выберите сервер")

    rows = await db.fetch("""
        SELECT b.boss_name, b.level, d.dungeon_name
        FROM   boss b
        JOIN   dungeon d USING(dungeon_id)
        WHERE  d.server_id = $1
        ORDER  BY b.level DESC
    """, sid)

    txt = "\n".join(
        f"{r['boss_name']} — ур.{r['level']} ({r['dungeon_name']})"
        for r in rows) or "боссы не добавлены"
    await stat_ans(e, f"👹 Список боссов:\n{txt}")


@client.on(events.CallbackQuery(data=b"s7"))
async def s7(e):
    sid=stat_sid(e.sender_id)
    if not sid: return await stat_ans(e,"Выберите сервер")
    await db.execute("""
      UPDATE player_character
      SET experience=experience +
        CASE WHEN level<5 THEN 500 WHEN level<10 THEN 250 ELSE 100 END
      WHERE server_id=$1""",sid)
    await stat_ans(e,"⚙ Опыт начислен!")

@client.on(events.CallbackQuery(data=b"s8"))
async def s8(e):
    sid=stat_sid(e.sender_id)
    if not sid: return await stat_ans(e,"Выберите сервер")
    rows=await db.fetch("""
      SELECT c.character_name,i.damage
      FROM equipment e JOIN item i USING(item_id)
      JOIN player_character c USING(character_id)
      WHERE e.is_equipped AND i.item_type='weapon' AND c.server_id=$1""",sid)
    txt="\n".join(f"{r['character_name']}: {r['damage']} dmg" for r in rows) or "нет"
    await stat_ans(e,f"🔥 Урон оружия:\n{txt}")

@client.on(events.CallbackQuery(data=b"s9"))
async def s9_dungeons(e):
    sid = stat_sid(e.sender_id)
    if not sid:
        return await stat_ans(e, "Выберите сервер")

    rows = await db.fetch("""
        SELECT d.dungeon_name, d.difficulty, l.location_name
        FROM   dungeon d
        JOIN   location l USING(location_id)
        WHERE  d.server_id = $1
        ORDER  BY d.difficulty DESC
    """, sid)

    txt = "\n".join(
        f"{r['dungeon_name']} (сложн. {r['difficulty']}) — {r['location_name']}"
        for r in rows) or "подземелий нет"
    await stat_ans(e, f"🏰 Подземелья:\n{txt}")

# ───— новые вспомогательные "состояния" —─────────────────────
ask_loc_step   = {}          # uid -> step (0,1,2) + temp data
ask_mob_step   = {}          # uid -> step + dict

# ───— 1. СОЗДАНИЕ ЛОКАЦИИ —───────────────────────────────────
@client.on(events.CallbackQuery(data=b"loc_add"))
async def loc_add_start(e):
    uid = e.sender_id
    ask_loc_step[uid] = {"step": 0, "data": {}}      # очистили буфер
    await e.respond("Введите НАЗВАНИЕ новой локации:")

@client.on(events.NewMessage)
async def on_text_all(e):
    uid = e.sender_id
    txt = e.raw_text.strip()

    if uid in ask_loc_step:
        st = ask_loc_step[uid]["step"]
        dat = ask_loc_step[uid]["data"]

        if st == 0:                       # получили название
            dat["name"] = txt
            ask_loc_step[uid]["step"] = 1
            return await e.respond("Минимальный уровень (целое число >=1):")

        if st == 1:                       # получили min_level
            if not txt.isdigit() or int(txt) < 1:
                return await e.respond("Введите положительное число!")
            dat["min_level"] = int(txt)
            ask_loc_step[uid]["step"] = 2
            return await e.respond("PVP-зона? (0 = нет, 1 = да):")

        if st == 2:                       # получили pvp
            if txt not in ("0", "1"):
                return await e.respond("Введите 0 или 1.")
            dat["is_pvp"] = bool(int(txt))
            sid = sess_game.get(uid)
            await db.execute("""
                INSERT INTO location (location_name,min_level,is_pvp,server_id)
                VALUES ($1,$2,$3,$4)
            """, dat["name"], dat["min_level"], dat["is_pvp"], sid)
            ask_loc_step.pop(uid, None)
            return await e.respond(f"✅ Локация «{dat['name']}» создана.", buttons=BACK_MAIN)

@client.on(events.CallbackQuery(data=lambda d: d.startswith(b"mob_loc_")))
async def mob_loc_chosen(e):
    uid    = e.sender_id
    loc_id = int(e.data.decode().split("_")[-1])

    ask_mob_step[uid] = {"step": 0, "data": {"loc_id": loc_id}}
    await e.respond("Имя моба:")

# ───— 2. СОЗДАНИЕ МОБА —──────────────────────────────────────
@client.on(events.CallbackQuery(data=b"mob_add"))
async def mob_add_start(e):
    uid = e.sender_id
    sid = sess_game.get(uid)
    rows = await db.fetch("SELECT location_id,location_name FROM location WHERE server_id=$1", sid)
    if not rows:
        return await e.respond("На сервере ещё нет локаций.", buttons=BACK_MAIN)

    kb = [row(KeyboardButtonCallback(r["location_name"], f"mob_loc_{r['location_id']}".encode())) for r in rows]
    kb.append(row(KeyboardButtonCallback("⬅ Назад", b"menu")))
    await e.respond("Выберите локацию, где появится моб:", buttons=ReplyInlineMarkup(kb))



# ───── MAIN ──────────────────────────────────────────
async def main():
    global db
    db = await pg_connect()
    await client.start(bot_token=bot_token)
    print("🤖 Бот online"); await client.run_until_disconnected()

if __name__=="__main__":
    asyncio.run(main())
