--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

-- Started on 2025-06-22 21:35:56

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 251 (class 1255 OID 16721)
-- Name: cap_drop_chance(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cap_drop_chance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.drop_chance > 1 THEN
        NEW.drop_chance := 1;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.cap_drop_chance() OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 16719)
-- Name: check_equipped_item_exists(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_equipped_item_exists() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    item_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO item_count
    FROM player_item
    WHERE character_id = NEW.character_id AND item_id = NEW.item_id;

    IF item_count = 0 THEN
        RAISE EXCEPTION 'Нельзя экипировать предмет, которого нет в инвентаре';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_equipped_item_exists() OWNER TO postgres;

--
-- TOC entry 248 (class 1255 OID 16715)
-- Name: give_starter_item(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.give_starter_item() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO player_item (character_id, item_id, quantity)
    VALUES (NEW.character_id, 1, 1);
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.give_starter_item() OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 16717)
-- Name: log_level_up(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_level_up() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.level > OLD.level THEN
        INSERT INTO event_log(character_id, action)
        VALUES (NEW.character_id, CONCAT('Уровень повышен до ', NEW.level));
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_level_up() OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 16713)
-- Name: prevent_negative_items(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prevent_negative_items() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.quantity < 0 THEN
        RAISE EXCEPTION 'Нельзя добавить предмет с отрицательным количеством!';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.prevent_negative_items() OWNER TO postgres;

--
-- TOC entry 252 (class 1255 OID 16711)
-- Name: set_default_character_values(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_default_character_values() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.level := 1;
    NEW.experience := 0;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_default_character_values() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 244 (class 1259 OID 16686)
-- Name: active_ability; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.active_ability (
    ability_id integer NOT NULL,
    class_id integer NOT NULL,
    ability_name character varying(100) NOT NULL,
    description text,
    mana_cost integer NOT NULL,
    cooldown integer NOT NULL,
    CONSTRAINT active_ability_cooldown_check CHECK ((cooldown >= 0)),
    CONSTRAINT active_ability_mana_cost_check CHECK ((mana_cost >= 0))
);


ALTER TABLE public.active_ability OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 16685)
-- Name: active_ability_ability_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.active_ability_ability_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.active_ability_ability_id_seq OWNER TO postgres;

--
-- TOC entry 5070 (class 0 OID 0)
-- Dependencies: 243
-- Name: active_ability_ability_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.active_ability_ability_id_seq OWNED BY public.active_ability.ability_id;


--
-- TOC entry 232 (class 1259 OID 16545)
-- Name: boss; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.boss (
    boss_id integer NOT NULL,
    dungeon_id integer NOT NULL,
    boss_name character varying(100) NOT NULL,
    level integer NOT NULL,
    health integer NOT NULL,
    attack_power integer NOT NULL,
    CONSTRAINT boss_attack_power_check CHECK ((attack_power >= 0)),
    CONSTRAINT boss_health_check CHECK ((health > 0)),
    CONSTRAINT boss_level_check CHECK ((level >= 1))
);


ALTER TABLE public.boss OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16544)
-- Name: boss_boss_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.boss_boss_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.boss_boss_id_seq OWNER TO postgres;

--
-- TOC entry 5071 (class 0 OID 0)
-- Dependencies: 231
-- Name: boss_boss_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.boss_boss_id_seq OWNED BY public.boss.boss_id;


--
-- TOC entry 236 (class 1259 OID 16582)
-- Name: boss_drop; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.boss_drop (
    drop_id integer NOT NULL,
    boss_id integer NOT NULL,
    item_id integer NOT NULL,
    drop_chance real NOT NULL,
    min_quantity integer DEFAULT 1,
    max_quantity integer DEFAULT 1,
    CONSTRAINT boss_drop_check CHECK ((max_quantity >= min_quantity)),
    CONSTRAINT boss_drop_drop_chance_check CHECK (((drop_chance >= (0)::double precision) AND (drop_chance <= (1)::double precision))),
    CONSTRAINT boss_drop_min_quantity_check CHECK ((min_quantity >= 1))
);


ALTER TABLE public.boss_drop OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16581)
-- Name: boss_drop_drop_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.boss_drop_drop_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.boss_drop_drop_id_seq OWNER TO postgres;

--
-- TOC entry 5072 (class 0 OID 0)
-- Dependencies: 235
-- Name: boss_drop_drop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.boss_drop_drop_id_seq OWNED BY public.boss_drop.drop_id;


--
-- TOC entry 220 (class 1259 OID 16410)
-- Name: character_class; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.character_class (
    class_id integer NOT NULL,
    class_name character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.character_class OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16409)
-- Name: character_class_class_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.character_class_class_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.character_class_class_id_seq OWNER TO postgres;

--
-- TOC entry 5073 (class 0 OID 0)
-- Dependencies: 219
-- Name: character_class_class_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.character_class_class_id_seq OWNED BY public.character_class.class_id;


--
-- TOC entry 230 (class 1259 OID 16528)
-- Name: dungeon; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dungeon (
    dungeon_id integer NOT NULL,
    location_id integer NOT NULL,
    dungeon_name character varying(100) NOT NULL,
    description text,
    min_level integer DEFAULT 1 NOT NULL,
    difficulty integer,
    server_id integer NOT NULL,
    CONSTRAINT dungeon_difficulty_check CHECK (((difficulty >= 1) AND (difficulty <= 10))),
    CONSTRAINT dungeon_min_level_check CHECK ((min_level >= 1))
);


ALTER TABLE public.dungeon OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16527)
-- Name: dungeon_dungeon_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dungeon_dungeon_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dungeon_dungeon_id_seq OWNER TO postgres;

--
-- TOC entry 5074 (class 0 OID 0)
-- Dependencies: 229
-- Name: dungeon_dungeon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dungeon_dungeon_id_seq OWNED BY public.dungeon.dungeon_id;


--
-- TOC entry 240 (class 1259 OID 16653)
-- Name: equipment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.equipment (
    record_id integer NOT NULL,
    character_id integer NOT NULL,
    item_id integer NOT NULL,
    slot character varying(30) NOT NULL,
    is_equipped boolean DEFAULT true
);


ALTER TABLE public.equipment OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 16652)
-- Name: equipment_record_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.equipment_record_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.equipment_record_id_seq OWNER TO postgres;

--
-- TOC entry 5075 (class 0 OID 0)
-- Dependencies: 239
-- Name: equipment_record_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.equipment_record_id_seq OWNED BY public.equipment.record_id;


--
-- TOC entry 246 (class 1259 OID 16702)
-- Name: event_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_log (
    log_id integer NOT NULL,
    character_id integer,
    action text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.event_log OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 16701)
-- Name: event_log_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.event_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_log_log_id_seq OWNER TO postgres;

--
-- TOC entry 5076 (class 0 OID 0)
-- Dependencies: 245
-- Name: event_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.event_log_log_id_seq OWNED BY public.event_log.log_id;


--
-- TOC entry 226 (class 1259 OID 16491)
-- Name: item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.item (
    item_id integer NOT NULL,
    item_name character varying(100) NOT NULL,
    description text,
    item_type character varying(30) NOT NULL,
    required_level integer DEFAULT 1,
    rarity character varying(20),
    is_tradeable boolean DEFAULT true,
    sell_price integer DEFAULT 0,
    damage integer,
    attack_speed real,
    damage_type character varying(20),
    armor_slot character varying(20),
    defense integer,
    magic_resistance integer,
    durability integer DEFAULT 100,
    special_effects text,
    CONSTRAINT item_attack_speed_check CHECK ((attack_speed >= (0)::double precision)),
    CONSTRAINT item_damage_check CHECK ((damage >= 0)),
    CONSTRAINT item_defense_check CHECK ((defense >= 0)),
    CONSTRAINT item_durability_check CHECK ((durability >= 0)),
    CONSTRAINT item_item_type_check CHECK (((item_type)::text = ANY ((ARRAY['weapon'::character varying, 'armor'::character varying, 'artifact'::character varying, 'misc'::character varying])::text[]))),
    CONSTRAINT item_magic_resistance_check CHECK ((magic_resistance >= 0)),
    CONSTRAINT item_rarity_check CHECK (((rarity)::text = ANY ((ARRAY['common'::character varying, 'uncommon'::character varying, 'rare'::character varying, 'epic'::character varying, 'legendary'::character varying])::text[]))),
    CONSTRAINT item_required_level_check CHECK ((required_level >= 1)),
    CONSTRAINT item_sell_price_check CHECK ((sell_price >= 0))
);


ALTER TABLE public.item OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16490)
-- Name: item_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.item_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.item_item_id_seq OWNER TO postgres;

--
-- TOC entry 5077 (class 0 OID 0)
-- Dependencies: 225
-- Name: item_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.item_item_id_seq OWNED BY public.item.item_id;


--
-- TOC entry 222 (class 1259 OID 16419)
-- Name: location; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.location (
    location_id integer NOT NULL,
    location_name character varying(50) NOT NULL,
    description text,
    min_level integer DEFAULT 1,
    is_pvp boolean DEFAULT false,
    server_id integer NOT NULL,
    CONSTRAINT location_min_level_check CHECK ((min_level >= 1))
);


ALTER TABLE public.location OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16418)
-- Name: location_location_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.location_location_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.location_location_id_seq OWNER TO postgres;

--
-- TOC entry 5078 (class 0 OID 0)
-- Dependencies: 221
-- Name: location_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.location_location_id_seq OWNED BY public.location.location_id;


--
-- TOC entry 228 (class 1259 OID 16513)
-- Name: mob; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mob (
    mob_id integer NOT NULL,
    location_id integer NOT NULL,
    mob_name character varying(50) NOT NULL,
    level integer NOT NULL,
    health integer NOT NULL,
    attack_power integer NOT NULL,
    CONSTRAINT mob_attack_power_check CHECK ((attack_power >= 0)),
    CONSTRAINT mob_health_check CHECK ((health > 0)),
    CONSTRAINT mob_level_check CHECK ((level >= 1))
);


ALTER TABLE public.mob OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 16560)
-- Name: mob_drop; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mob_drop (
    drop_id integer NOT NULL,
    mob_id integer NOT NULL,
    item_id integer NOT NULL,
    drop_chance real NOT NULL,
    min_quantity integer DEFAULT 1,
    max_quantity integer DEFAULT 1,
    CONSTRAINT mob_drop_check CHECK ((max_quantity >= min_quantity)),
    CONSTRAINT mob_drop_drop_chance_check CHECK (((drop_chance >= (0)::double precision) AND (drop_chance <= (1)::double precision))),
    CONSTRAINT mob_drop_min_quantity_check CHECK ((min_quantity >= 1))
);


ALTER TABLE public.mob_drop OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 16559)
-- Name: mob_drop_drop_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mob_drop_drop_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mob_drop_drop_id_seq OWNER TO postgres;

--
-- TOC entry 5079 (class 0 OID 0)
-- Dependencies: 233
-- Name: mob_drop_drop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mob_drop_drop_id_seq OWNED BY public.mob_drop.drop_id;


--
-- TOC entry 227 (class 1259 OID 16512)
-- Name: mob_mob_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mob_mob_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mob_mob_id_seq OWNER TO postgres;

--
-- TOC entry 5080 (class 0 OID 0)
-- Dependencies: 227
-- Name: mob_mob_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mob_mob_id_seq OWNED BY public.mob.mob_id;


--
-- TOC entry 242 (class 1259 OID 16672)
-- Name: passive_ability; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.passive_ability (
    ability_id integer NOT NULL,
    class_id integer NOT NULL,
    ability_name character varying(100) NOT NULL,
    description text,
    effect text
);


ALTER TABLE public.passive_ability OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 16671)
-- Name: passive_ability_ability_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.passive_ability_ability_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.passive_ability_ability_id_seq OWNER TO postgres;

--
-- TOC entry 5081 (class 0 OID 0)
-- Dependencies: 241
-- Name: passive_ability_ability_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.passive_ability_ability_id_seq OWNED BY public.passive_ability.ability_id;


--
-- TOC entry 224 (class 1259 OID 16461)
-- Name: player_character; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.player_character (
    character_id integer NOT NULL,
    server_id integer NOT NULL,
    class_id integer NOT NULL,
    location_id integer NOT NULL,
    character_name character varying(50) NOT NULL,
    level integer DEFAULT 1 NOT NULL,
    experience integer DEFAULT 0 NOT NULL,
    is_moderator boolean DEFAULT false NOT NULL,
    CONSTRAINT player_character_experience_check CHECK ((experience >= 0)),
    CONSTRAINT player_character_level_check CHECK ((level >= 1))
);


ALTER TABLE public.player_character OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16460)
-- Name: player_character_character_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.player_character_character_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.player_character_character_id_seq OWNER TO postgres;

--
-- TOC entry 5082 (class 0 OID 0)
-- Dependencies: 223
-- Name: player_character_character_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.player_character_character_id_seq OWNED BY public.player_character.character_id;


--
-- TOC entry 238 (class 1259 OID 16625)
-- Name: player_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.player_item (
    record_id integer NOT NULL,
    character_id integer NOT NULL,
    item_id integer NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    acquired_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT player_item_quantity_check CHECK ((quantity >= 0))
);


ALTER TABLE public.player_item OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 16624)
-- Name: player_item_record_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.player_item_record_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.player_item_record_id_seq OWNER TO postgres;

--
-- TOC entry 5083 (class 0 OID 0)
-- Dependencies: 237
-- Name: player_item_record_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.player_item_record_id_seq OWNED BY public.player_item.record_id;


--
-- TOC entry 218 (class 1259 OID 16402)
-- Name: server; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.server (
    server_id integer NOT NULL,
    server_name character varying(50) NOT NULL,
    region character varying(50),
    is_active boolean DEFAULT true
);


ALTER TABLE public.server OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 16401)
-- Name: server_server_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.server_server_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.server_server_id_seq OWNER TO postgres;

--
-- TOC entry 5084 (class 0 OID 0)
-- Dependencies: 217
-- Name: server_server_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.server_server_id_seq OWNED BY public.server.server_id;


--
-- TOC entry 4802 (class 2604 OID 16689)
-- Name: active_ability ability_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.active_ability ALTER COLUMN ability_id SET DEFAULT nextval('public.active_ability_ability_id_seq'::regclass);


--
-- TOC entry 4789 (class 2604 OID 16548)
-- Name: boss boss_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.boss ALTER COLUMN boss_id SET DEFAULT nextval('public.boss_boss_id_seq'::regclass);


--
-- TOC entry 4793 (class 2604 OID 16585)
-- Name: boss_drop drop_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.boss_drop ALTER COLUMN drop_id SET DEFAULT nextval('public.boss_drop_drop_id_seq'::regclass);


--
-- TOC entry 4773 (class 2604 OID 16413)
-- Name: character_class class_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.character_class ALTER COLUMN class_id SET DEFAULT nextval('public.character_class_class_id_seq'::regclass);


--
-- TOC entry 4787 (class 2604 OID 16531)
-- Name: dungeon dungeon_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dungeon ALTER COLUMN dungeon_id SET DEFAULT nextval('public.dungeon_dungeon_id_seq'::regclass);


--
-- TOC entry 4799 (class 2604 OID 16656)
-- Name: equipment record_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment ALTER COLUMN record_id SET DEFAULT nextval('public.equipment_record_id_seq'::regclass);


--
-- TOC entry 4803 (class 2604 OID 16705)
-- Name: event_log log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_log ALTER COLUMN log_id SET DEFAULT nextval('public.event_log_log_id_seq'::regclass);


--
-- TOC entry 4781 (class 2604 OID 16494)
-- Name: item item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.item ALTER COLUMN item_id SET DEFAULT nextval('public.item_item_id_seq'::regclass);


--
-- TOC entry 4774 (class 2604 OID 16422)
-- Name: location location_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location ALTER COLUMN location_id SET DEFAULT nextval('public.location_location_id_seq'::regclass);


--
-- TOC entry 4786 (class 2604 OID 16516)
-- Name: mob mob_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mob ALTER COLUMN mob_id SET DEFAULT nextval('public.mob_mob_id_seq'::regclass);


--
-- TOC entry 4790 (class 2604 OID 16563)
-- Name: mob_drop drop_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mob_drop ALTER COLUMN drop_id SET DEFAULT nextval('public.mob_drop_drop_id_seq'::regclass);


--
-- TOC entry 4801 (class 2604 OID 16675)
-- Name: passive_ability ability_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.passive_ability ALTER COLUMN ability_id SET DEFAULT nextval('public.passive_ability_ability_id_seq'::regclass);


--
-- TOC entry 4777 (class 2604 OID 16464)
-- Name: player_character character_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_character ALTER COLUMN character_id SET DEFAULT nextval('public.player_character_character_id_seq'::regclass);


--
-- TOC entry 4796 (class 2604 OID 16628)
-- Name: player_item record_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_item ALTER COLUMN record_id SET DEFAULT nextval('public.player_item_record_id_seq'::regclass);


--
-- TOC entry 4771 (class 2604 OID 16405)
-- Name: server server_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.server ALTER COLUMN server_id SET DEFAULT nextval('public.server_server_id_seq'::regclass);


--
-- TOC entry 4863 (class 2606 OID 16695)
-- Name: active_ability active_ability_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.active_ability
    ADD CONSTRAINT active_ability_pkey PRIMARY KEY (ability_id);


--
-- TOC entry 4855 (class 2606 OID 16592)
-- Name: boss_drop boss_drop_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.boss_drop
    ADD CONSTRAINT boss_drop_pkey PRIMARY KEY (drop_id);


--
-- TOC entry 4851 (class 2606 OID 16553)
-- Name: boss boss_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.boss
    ADD CONSTRAINT boss_pkey PRIMARY KEY (boss_id);


--
-- TOC entry 4837 (class 2606 OID 16417)
-- Name: character_class character_class_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.character_class
    ADD CONSTRAINT character_class_pkey PRIMARY KEY (class_id);


--
-- TOC entry 4849 (class 2606 OID 16538)
-- Name: dungeon dungeon_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dungeon
    ADD CONSTRAINT dungeon_pkey PRIMARY KEY (dungeon_id);


--
-- TOC entry 4859 (class 2606 OID 16659)
-- Name: equipment equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_pkey PRIMARY KEY (record_id);


--
-- TOC entry 4865 (class 2606 OID 16710)
-- Name: event_log event_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_log
    ADD CONSTRAINT event_log_pkey PRIMARY KEY (log_id);


--
-- TOC entry 4845 (class 2606 OID 16511)
-- Name: item item_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.item
    ADD CONSTRAINT item_pkey PRIMARY KEY (item_id);


--
-- TOC entry 4839 (class 2606 OID 16429)
-- Name: location location_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location
    ADD CONSTRAINT location_pkey PRIMARY KEY (location_id);


--
-- TOC entry 4853 (class 2606 OID 16570)
-- Name: mob_drop mob_drop_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mob_drop
    ADD CONSTRAINT mob_drop_pkey PRIMARY KEY (drop_id);


--
-- TOC entry 4847 (class 2606 OID 16521)
-- Name: mob mob_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mob
    ADD CONSTRAINT mob_pkey PRIMARY KEY (mob_id);


--
-- TOC entry 4861 (class 2606 OID 16679)
-- Name: passive_ability passive_ability_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.passive_ability
    ADD CONSTRAINT passive_ability_pkey PRIMARY KEY (ability_id);


--
-- TOC entry 4841 (class 2606 OID 16473)
-- Name: player_character player_character_character_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_character
    ADD CONSTRAINT player_character_character_name_key UNIQUE (character_name);


--
-- TOC entry 4843 (class 2606 OID 16471)
-- Name: player_character player_character_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_character
    ADD CONSTRAINT player_character_pkey PRIMARY KEY (character_id);


--
-- TOC entry 4857 (class 2606 OID 16633)
-- Name: player_item player_item_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_item
    ADD CONSTRAINT player_item_pkey PRIMARY KEY (record_id);


--
-- TOC entry 4835 (class 2606 OID 16408)
-- Name: server server_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.server
    ADD CONSTRAINT server_pkey PRIMARY KEY (server_id);


--
-- TOC entry 4887 (class 2620 OID 16722)
-- Name: boss_drop trg_cap_boss_drop_chance; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_cap_boss_drop_chance BEFORE INSERT OR UPDATE ON public.boss_drop FOR EACH ROW EXECUTE FUNCTION public.cap_drop_chance();


--
-- TOC entry 4889 (class 2620 OID 16720)
-- Name: equipment trg_check_equipped_item_exists; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_equipped_item_exists BEFORE INSERT ON public.equipment FOR EACH ROW EXECUTE FUNCTION public.check_equipped_item_exists();


--
-- TOC entry 4884 (class 2620 OID 16712)
-- Name: player_character trg_default_character_values; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_default_character_values BEFORE INSERT ON public.player_character FOR EACH ROW EXECUTE FUNCTION public.set_default_character_values();


--
-- TOC entry 4885 (class 2620 OID 16716)
-- Name: player_character trg_give_starter_item; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_give_starter_item AFTER INSERT ON public.player_character FOR EACH ROW EXECUTE FUNCTION public.give_starter_item();


--
-- TOC entry 4886 (class 2620 OID 16718)
-- Name: player_character trg_log_level_up; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_log_level_up AFTER UPDATE ON public.player_character FOR EACH ROW EXECUTE FUNCTION public.log_level_up();


--
-- TOC entry 4888 (class 2620 OID 16714)
-- Name: player_item trg_prevent_negative_items; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_prevent_negative_items BEFORE INSERT OR UPDATE ON public.player_item FOR EACH ROW EXECUTE FUNCTION public.prevent_negative_items();


--
-- TOC entry 4883 (class 2606 OID 16696)
-- Name: active_ability fk_activeability_class; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.active_ability
    ADD CONSTRAINT fk_activeability_class FOREIGN KEY (class_id) REFERENCES public.character_class(class_id) ON DELETE CASCADE;


--
-- TOC entry 4873 (class 2606 OID 16554)
-- Name: boss fk_boss_dungeon; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.boss
    ADD CONSTRAINT fk_boss_dungeon FOREIGN KEY (dungeon_id) REFERENCES public.dungeon(dungeon_id) ON DELETE CASCADE;


--
-- TOC entry 4876 (class 2606 OID 16593)
-- Name: boss_drop fk_bossdrop_boss; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.boss_drop
    ADD CONSTRAINT fk_bossdrop_boss FOREIGN KEY (boss_id) REFERENCES public.boss(boss_id) ON DELETE CASCADE;


--
-- TOC entry 4877 (class 2606 OID 16598)
-- Name: boss_drop fk_bossdrop_item; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.boss_drop
    ADD CONSTRAINT fk_bossdrop_item FOREIGN KEY (item_id) REFERENCES public.item(item_id) ON DELETE CASCADE;


--
-- TOC entry 4867 (class 2606 OID 16479)
-- Name: player_character fk_character_class; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_character
    ADD CONSTRAINT fk_character_class FOREIGN KEY (class_id) REFERENCES public.character_class(class_id) ON DELETE RESTRICT;


--
-- TOC entry 4868 (class 2606 OID 16484)
-- Name: player_character fk_character_location; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_character
    ADD CONSTRAINT fk_character_location FOREIGN KEY (location_id) REFERENCES public.location(location_id) ON DELETE SET NULL;


--
-- TOC entry 4869 (class 2606 OID 16474)
-- Name: player_character fk_character_server; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_character
    ADD CONSTRAINT fk_character_server FOREIGN KEY (server_id) REFERENCES public.server(server_id) ON DELETE CASCADE;


--
-- TOC entry 4871 (class 2606 OID 16539)
-- Name: dungeon fk_dungeon_location; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dungeon
    ADD CONSTRAINT fk_dungeon_location FOREIGN KEY (location_id) REFERENCES public.location(location_id) ON DELETE CASCADE;


--
-- TOC entry 4872 (class 2606 OID 16739)
-- Name: dungeon fk_dungeon_server; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dungeon
    ADD CONSTRAINT fk_dungeon_server FOREIGN KEY (server_id) REFERENCES public.server(server_id) ON DELETE CASCADE;


--
-- TOC entry 4880 (class 2606 OID 16660)
-- Name: equipment fk_equipment_character; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT fk_equipment_character FOREIGN KEY (character_id) REFERENCES public.player_character(character_id) ON DELETE CASCADE;


--
-- TOC entry 4881 (class 2606 OID 16665)
-- Name: equipment fk_equipment_item; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT fk_equipment_item FOREIGN KEY (item_id) REFERENCES public.item(item_id) ON DELETE CASCADE;


--
-- TOC entry 4866 (class 2606 OID 16734)
-- Name: location fk_location_server; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.location
    ADD CONSTRAINT fk_location_server FOREIGN KEY (server_id) REFERENCES public.server(server_id) ON DELETE CASCADE;


--
-- TOC entry 4870 (class 2606 OID 16522)
-- Name: mob fk_mob_location; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mob
    ADD CONSTRAINT fk_mob_location FOREIGN KEY (location_id) REFERENCES public.location(location_id) ON DELETE CASCADE;


--
-- TOC entry 4874 (class 2606 OID 16576)
-- Name: mob_drop fk_mobdrop_item; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mob_drop
    ADD CONSTRAINT fk_mobdrop_item FOREIGN KEY (item_id) REFERENCES public.item(item_id) ON DELETE CASCADE;


--
-- TOC entry 4875 (class 2606 OID 16571)
-- Name: mob_drop fk_mobdrop_mob; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mob_drop
    ADD CONSTRAINT fk_mobdrop_mob FOREIGN KEY (mob_id) REFERENCES public.mob(mob_id) ON DELETE CASCADE;


--
-- TOC entry 4882 (class 2606 OID 16680)
-- Name: passive_ability fk_passiveability_class; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.passive_ability
    ADD CONSTRAINT fk_passiveability_class FOREIGN KEY (class_id) REFERENCES public.character_class(class_id) ON DELETE CASCADE;


--
-- TOC entry 4878 (class 2606 OID 16634)
-- Name: player_item fk_playeritem_character; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_item
    ADD CONSTRAINT fk_playeritem_character FOREIGN KEY (character_id) REFERENCES public.player_character(character_id) ON DELETE CASCADE;


--
-- TOC entry 4879 (class 2606 OID 16639)
-- Name: player_item fk_playeritem_item; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.player_item
    ADD CONSTRAINT fk_playeritem_item FOREIGN KEY (item_id) REFERENCES public.item(item_id) ON DELETE CASCADE;


-- Completed on 2025-06-22 21:35:56

--
-- PostgreSQL database dump complete
--

