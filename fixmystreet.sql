--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: problem_nearby_match; Type: TYPE; Schema: public; Owner: fms
--

CREATE TYPE problem_nearby_match AS (
	problem_id integer,
	distance double precision
);


ALTER TYPE public.problem_nearby_match OWNER TO fms;

--
-- Name: contacts_updated(); Type: FUNCTION; Schema: public; Owner: fms
--

CREATE FUNCTION contacts_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    begin
        insert into contacts_history (contact_id, body_id, category, email, editor, whenedited, note, confirmed, deleted) values (new.id, new.body_id, new.category, new.email, new.editor, new.whenedited, new.note, new.confirmed, new.deleted);
        return new;
    end;
$$;


ALTER FUNCTION public.contacts_updated() OWNER TO fms;

--
-- Name: problem_find_nearby(double precision, double precision, double precision); Type: FUNCTION; Schema: public; Owner: fms
--

CREATE FUNCTION problem_find_nearby(double precision, double precision, double precision) RETURNS SETOF problem_nearby_match
    LANGUAGE sql STABLE
    AS $_$
    -- trunc due to inaccuracies in floating point arithmetic
    select problem.id,
           R_e() * acos(trunc(
                (sin(radians($1)) * sin(radians(latitude))
                + cos(radians($1)) * cos(radians(latitude))
                    * cos(radians($2 - longitude)))::numeric, 14)
            ) as distance
        from problem
        where
            longitude is not null and latitude is not null
            and radians(latitude) > radians($1) - ($3 / R_e())
            and radians(latitude) < radians($1) + ($3 / R_e())
            and (
                abs(radians($1)) + ($3 / R_e()) > pi() / 2     -- case where search pt is near pole
                or (
                        radians(longitude) > radians($2) - asin(sin($3 / R_e())/cos(radians($1)))
                    and radians(longitude) < radians($2) + asin(sin($3 / R_e())/cos(radians($1)))
                )
            )
            -- ugly -- unable to use attribute name "distance" here, sadly
            and R_e() * acos(trunc(
                (sin(radians($1)) * sin(radians(latitude))
                + cos(radians($1)) * cos(radians(latitude))
                    * cos(radians($2 - longitude)))::numeric, 14)
                ) < $3
        order by distance desc
$_$;


ALTER FUNCTION public.problem_find_nearby(double precision, double precision, double precision) OWNER TO fms;

--
-- Name: r_e(); Type: FUNCTION; Schema: public; Owner: fms
--

CREATE FUNCTION r_e() RETURNS double precision
    LANGUAGE sql IMMUTABLE
    AS $$
select 6372.8::double precision;
$$;


ALTER FUNCTION public.r_e() OWNER TO fms;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: abuse; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE abuse (
    email text NOT NULL,
    CONSTRAINT abuse_email_check CHECK ((lower(email) = email))
);


ALTER TABLE public.abuse OWNER TO fms;

--
-- Name: admin_log; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE admin_log (
    id integer NOT NULL,
    admin_user text NOT NULL,
    object_type text NOT NULL,
    object_id integer NOT NULL,
    action text NOT NULL,
    whenedited timestamp without time zone DEFAULT now() NOT NULL,
    user_id integer,
    reason text DEFAULT ''::text NOT NULL,
    time_spent integer DEFAULT 0 NOT NULL,
    CONSTRAINT admin_log_object_type_check CHECK ((((object_type = 'problem'::text) OR (object_type = 'update'::text)) OR (object_type = 'user'::text)))
);


ALTER TABLE public.admin_log OWNER TO fms;

--
-- Name: admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.admin_log_id_seq OWNER TO fms;

--
-- Name: admin_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE admin_log_id_seq OWNED BY admin_log.id;


--
-- Name: alert; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE alert (
    id integer NOT NULL,
    alert_type text NOT NULL,
    parameter text,
    parameter2 text,
    user_id integer NOT NULL,
    confirmed integer DEFAULT 0 NOT NULL,
    lang text DEFAULT 'en-gb'::text NOT NULL,
    cobrand text DEFAULT ''::text NOT NULL,
    cobrand_data text DEFAULT ''::text NOT NULL,
    whensubscribed timestamp without time zone DEFAULT now() NOT NULL,
    whendisabled timestamp without time zone,
    CONSTRAINT alert_cobrand_check CHECK ((cobrand ~* '^[a-z0-9_]*$'::text)),
    CONSTRAINT alert_cobrand_data_check CHECK ((cobrand_data ~* '^[a-z0-9_]*$'::text))
);


ALTER TABLE public.alert OWNER TO fms;

--
-- Name: alert_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE alert_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alert_id_seq OWNER TO fms;

--
-- Name: alert_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE alert_id_seq OWNED BY alert.id;


--
-- Name: alert_sent; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE alert_sent (
    alert_id integer NOT NULL,
    parameter text,
    whenqueued timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.alert_sent OWNER TO fms;

--
-- Name: alert_type; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE alert_type (
    ref text NOT NULL,
    head_sql_query text NOT NULL,
    head_table text NOT NULL,
    head_title text NOT NULL,
    head_link text NOT NULL,
    head_description text NOT NULL,
    item_table text NOT NULL,
    item_where text NOT NULL,
    item_order text NOT NULL,
    item_title text NOT NULL,
    item_link text NOT NULL,
    item_description text NOT NULL,
    template text NOT NULL
);


ALTER TABLE public.alert_type OWNER TO fms;

--
-- Name: body; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE body (
    id integer NOT NULL,
    name text NOT NULL,
    external_url text,
    parent integer,
    endpoint text,
    jurisdiction text,
    api_key text,
    send_method text,
    send_comments boolean DEFAULT false NOT NULL,
    comment_user_id integer,
    suppress_alerts boolean DEFAULT false NOT NULL,
    can_be_devolved boolean DEFAULT false NOT NULL,
    send_extended_statuses boolean DEFAULT false NOT NULL,
    deleted boolean DEFAULT false NOT NULL
);


ALTER TABLE public.body OWNER TO fms;

--
-- Name: body_areas; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE body_areas (
    body_id integer NOT NULL,
    area_id integer NOT NULL
);


ALTER TABLE public.body_areas OWNER TO fms;

--
-- Name: body_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE body_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.body_id_seq OWNER TO fms;

--
-- Name: body_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE body_id_seq OWNED BY body.id;


--
-- Name: comment; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE comment (
    id integer NOT NULL,
    problem_id integer NOT NULL,
    user_id integer NOT NULL,
    anonymous boolean NOT NULL,
    name text,
    website text,
    created timestamp without time zone DEFAULT now() NOT NULL,
    confirmed timestamp without time zone,
    text text NOT NULL,
    photo bytea,
    state text NOT NULL,
    cobrand text DEFAULT ''::text NOT NULL,
    lang text DEFAULT 'en-gb'::text NOT NULL,
    cobrand_data text DEFAULT ''::text NOT NULL,
    mark_fixed boolean NOT NULL,
    mark_open boolean DEFAULT false NOT NULL,
    problem_state text,
    external_id text,
    extra text,
    send_fail_count integer DEFAULT 0 NOT NULL,
    send_fail_reason text,
    send_fail_timestamp timestamp without time zone,
    whensent timestamp without time zone,
    CONSTRAINT comment_cobrand_check CHECK ((cobrand ~* '^[a-z0-9_]*$'::text)),
    CONSTRAINT comment_cobrand_data_check CHECK ((cobrand_data ~* '^[a-z0-9_]*$'::text)),
    CONSTRAINT comment_problem_state_check CHECK ((((((((((((((problem_state = 'confirmed'::text) OR (problem_state = 'investigating'::text)) OR (problem_state = 'planned'::text)) OR (problem_state = 'in progress'::text)) OR (problem_state = 'action scheduled'::text)) OR (problem_state = 'closed'::text)) OR (problem_state = 'fixed'::text)) OR (problem_state = 'fixed - council'::text)) OR (problem_state = 'fixed - user'::text)) OR (problem_state = 'unable to fix'::text)) OR (problem_state = 'not responsible'::text)) OR (problem_state = 'duplicate'::text)) OR (problem_state = 'internal referral'::text))),
    CONSTRAINT comment_state_check CHECK ((((state = 'unconfirmed'::text) OR (state = 'confirmed'::text)) OR (state = 'hidden'::text)))
);


ALTER TABLE public.comment OWNER TO fms;

--
-- Name: comment_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE comment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.comment_id_seq OWNER TO fms;

--
-- Name: comment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE comment_id_seq OWNED BY comment.id;


--
-- Name: contact_response_priorities; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE contact_response_priorities (
    id integer NOT NULL,
    contact_id integer NOT NULL,
    response_priority_id integer NOT NULL
);


ALTER TABLE public.contact_response_priorities OWNER TO fms;

--
-- Name: contact_response_priorities_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE contact_response_priorities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contact_response_priorities_id_seq OWNER TO fms;

--
-- Name: contact_response_priorities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE contact_response_priorities_id_seq OWNED BY contact_response_priorities.id;


--
-- Name: contact_response_templates; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE contact_response_templates (
    id integer NOT NULL,
    contact_id integer NOT NULL,
    response_template_id integer NOT NULL
);


ALTER TABLE public.contact_response_templates OWNER TO fms;

--
-- Name: contact_response_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE contact_response_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contact_response_templates_id_seq OWNER TO fms;

--
-- Name: contact_response_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE contact_response_templates_id_seq OWNED BY contact_response_templates.id;


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE contacts (
    id integer NOT NULL,
    body_id integer NOT NULL,
    category text DEFAULT 'Other'::text NOT NULL,
    email text NOT NULL,
    confirmed boolean NOT NULL,
    deleted boolean NOT NULL,
    editor text NOT NULL,
    whenedited timestamp without time zone NOT NULL,
    note text NOT NULL,
    extra text,
    non_public boolean DEFAULT false,
    endpoint text,
    jurisdiction text DEFAULT ''::text,
    api_key text DEFAULT ''::text,
    send_method text
);


ALTER TABLE public.contacts OWNER TO fms;

--
-- Name: contacts_history; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE contacts_history (
    contacts_history_id integer NOT NULL,
    contact_id integer NOT NULL,
    body_id integer NOT NULL,
    category text DEFAULT 'Other'::text NOT NULL,
    email text NOT NULL,
    confirmed boolean NOT NULL,
    deleted boolean NOT NULL,
    editor text NOT NULL,
    whenedited timestamp without time zone NOT NULL,
    note text NOT NULL
);


ALTER TABLE public.contacts_history OWNER TO fms;

--
-- Name: contacts_history_contacts_history_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE contacts_history_contacts_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contacts_history_contacts_history_id_seq OWNER TO fms;

--
-- Name: contacts_history_contacts_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE contacts_history_contacts_history_id_seq OWNED BY contacts_history.contacts_history_id;


--
-- Name: contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contacts_id_seq OWNER TO fms;

--
-- Name: contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE contacts_id_seq OWNED BY contacts.id;


--
-- Name: flickr_imported; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE flickr_imported (
    id text NOT NULL,
    problem_id integer NOT NULL
);


ALTER TABLE public.flickr_imported OWNER TO fms;

--
-- Name: moderation_original_data; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE moderation_original_data (
    id integer NOT NULL,
    problem_id integer NOT NULL,
    comment_id integer,
    title text,
    detail text,
    photo bytea,
    anonymous boolean NOT NULL,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.moderation_original_data OWNER TO fms;

--
-- Name: moderation_original_data_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE moderation_original_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.moderation_original_data_id_seq OWNER TO fms;

--
-- Name: moderation_original_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE moderation_original_data_id_seq OWNED BY moderation_original_data.id;


--
-- Name: partial_user; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE partial_user (
    id integer NOT NULL,
    service text NOT NULL,
    nsid text NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    phone text NOT NULL
);


ALTER TABLE public.partial_user OWNER TO fms;

--
-- Name: partial_user_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE partial_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.partial_user_id_seq OWNER TO fms;

--
-- Name: partial_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE partial_user_id_seq OWNED BY partial_user.id;


--
-- Name: problem; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE problem (
    id integer NOT NULL,
    postcode text NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    bodies_str text,
    bodies_missing text,
    areas text NOT NULL,
    category text DEFAULT 'Other'::text NOT NULL,
    title text NOT NULL,
    detail text NOT NULL,
    photo bytea,
    used_map boolean NOT NULL,
    user_id integer NOT NULL,
    name text NOT NULL,
    anonymous boolean NOT NULL,
    external_id text,
    external_body text,
    external_team text,
    created timestamp without time zone DEFAULT now() NOT NULL,
    confirmed timestamp without time zone,
    state text NOT NULL,
    lang text DEFAULT 'en-gb'::text NOT NULL,
    service text DEFAULT ''::text NOT NULL,
    cobrand text DEFAULT ''::text NOT NULL,
    cobrand_data text DEFAULT ''::text NOT NULL,
    lastupdate timestamp without time zone DEFAULT now() NOT NULL,
    whensent timestamp without time zone,
    send_questionnaire boolean DEFAULT true NOT NULL,
    extra text,
    flagged boolean DEFAULT false NOT NULL,
    geocode bytea,
    response_priority_id integer,
    send_fail_count integer DEFAULT 0 NOT NULL,
    send_fail_reason text,
    send_fail_timestamp timestamp without time zone,
    send_method_used text,
    non_public boolean DEFAULT false,
    external_source text,
    external_source_id text,
    interest_count integer DEFAULT 0,
    subcategory text,
    CONSTRAINT problem_cobrand_check CHECK ((cobrand ~* '^[a-z0-9_]*$'::text)),
    CONSTRAINT problem_cobrand_data_check CHECK ((cobrand_data ~* '^[a-z0-9_]*$'::text)),
    CONSTRAINT problem_state_check CHECK (((((((((((((((((state = 'unconfirmed'::text) OR (state = 'confirmed'::text)) OR (state = 'investigating'::text)) OR (state = 'planned'::text)) OR (state = 'in progress'::text)) OR (state = 'action scheduled'::text)) OR (state = 'closed'::text)) OR (state = 'fixed'::text)) OR (state = 'fixed - council'::text)) OR (state = 'fixed - user'::text)) OR (state = 'hidden'::text)) OR (state = 'partial'::text)) OR (state = 'unable to fix'::text)) OR (state = 'not responsible'::text)) OR (state = 'duplicate'::text)) OR (state = 'internal referral'::text)))
);


ALTER TABLE public.problem OWNER TO fms;

--
-- Name: problem_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE problem_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.problem_id_seq OWNER TO fms;

--
-- Name: problem_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE problem_id_seq OWNED BY problem.id;


--
-- Name: questionnaire; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE questionnaire (
    id integer NOT NULL,
    problem_id integer NOT NULL,
    whensent timestamp without time zone NOT NULL,
    whenanswered timestamp without time zone,
    ever_reported boolean,
    old_state text,
    new_state text
);


ALTER TABLE public.questionnaire OWNER TO fms;

--
-- Name: questionnaire_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE questionnaire_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.questionnaire_id_seq OWNER TO fms;

--
-- Name: questionnaire_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE questionnaire_id_seq OWNED BY questionnaire.id;


--
-- Name: response_priorities; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE response_priorities (
    id integer NOT NULL,
    body_id integer NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    name text NOT NULL,
    description text
);


ALTER TABLE public.response_priorities OWNER TO fms;

--
-- Name: response_priorities_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE response_priorities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.response_priorities_id_seq OWNER TO fms;

--
-- Name: response_priorities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE response_priorities_id_seq OWNED BY response_priorities.id;


--
-- Name: response_templates; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE response_templates (
    id integer NOT NULL,
    body_id integer NOT NULL,
    title text NOT NULL,
    text text NOT NULL,
    created timestamp without time zone DEFAULT now() NOT NULL,
    auto_response boolean DEFAULT false NOT NULL
);


ALTER TABLE public.response_templates OWNER TO fms;

--
-- Name: response_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE response_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.response_templates_id_seq OWNER TO fms;

--
-- Name: response_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE response_templates_id_seq OWNED BY response_templates.id;


--
-- Name: secret; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE secret (
    secret text NOT NULL
);


ALTER TABLE public.secret OWNER TO fms;

--
-- Name: sessions; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE sessions (
    id character(72) NOT NULL,
    session_data text,
    expires integer
);


ALTER TABLE public.sessions OWNER TO fms;

--
-- Name: textmystreet; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE textmystreet (
    name text NOT NULL,
    email text NOT NULL,
    postcode text NOT NULL,
    mobile text NOT NULL
);


ALTER TABLE public.textmystreet OWNER TO fms;

--
-- Name: token; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE token (
    scope text NOT NULL,
    token text NOT NULL,
    data bytea NOT NULL,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.token OWNER TO fms;

--
-- Name: user_body_permissions; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE user_body_permissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    body_id integer NOT NULL,
    permission_type text NOT NULL
);


ALTER TABLE public.user_body_permissions OWNER TO fms;

--
-- Name: user_body_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE user_body_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_body_permissions_id_seq OWNER TO fms;

--
-- Name: user_body_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE user_body_permissions_id_seq OWNED BY user_body_permissions.id;


--
-- Name: user_planned_reports; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE user_planned_reports (
    id integer NOT NULL,
    user_id integer NOT NULL,
    report_id integer NOT NULL,
    added timestamp without time zone DEFAULT now() NOT NULL,
    removed timestamp without time zone
);


ALTER TABLE public.user_planned_reports OWNER TO fms;

--
-- Name: user_planned_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE user_planned_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_planned_reports_id_seq OWNER TO fms;

--
-- Name: user_planned_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE user_planned_reports_id_seq OWNED BY user_planned_reports.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: fms; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    email text NOT NULL,
    name text,
    phone text,
    password text DEFAULT ''::text NOT NULL,
    from_body integer,
    flagged boolean DEFAULT false NOT NULL,
    is_superuser boolean DEFAULT false NOT NULL,
    title text,
    twitter_id bigint,
    facebook_id bigint,
    area_id integer,
    extra text
);


ALTER TABLE public.users OWNER TO fms;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: fms
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO fms;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: fms
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY admin_log ALTER COLUMN id SET DEFAULT nextval('admin_log_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY alert ALTER COLUMN id SET DEFAULT nextval('alert_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY body ALTER COLUMN id SET DEFAULT nextval('body_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY comment ALTER COLUMN id SET DEFAULT nextval('comment_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contact_response_priorities ALTER COLUMN id SET DEFAULT nextval('contact_response_priorities_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contact_response_templates ALTER COLUMN id SET DEFAULT nextval('contact_response_templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contacts ALTER COLUMN id SET DEFAULT nextval('contacts_id_seq'::regclass);


--
-- Name: contacts_history_id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contacts_history ALTER COLUMN contacts_history_id SET DEFAULT nextval('contacts_history_contacts_history_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY moderation_original_data ALTER COLUMN id SET DEFAULT nextval('moderation_original_data_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY partial_user ALTER COLUMN id SET DEFAULT nextval('partial_user_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY problem ALTER COLUMN id SET DEFAULT nextval('problem_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY questionnaire ALTER COLUMN id SET DEFAULT nextval('questionnaire_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY response_priorities ALTER COLUMN id SET DEFAULT nextval('response_priorities_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY response_templates ALTER COLUMN id SET DEFAULT nextval('response_templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY user_body_permissions ALTER COLUMN id SET DEFAULT nextval('user_body_permissions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY user_planned_reports ALTER COLUMN id SET DEFAULT nextval('user_planned_reports_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: fms
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Data for Name: abuse; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY abuse (email) FROM stdin;
\.


--
-- Data for Name: admin_log; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY admin_log (id, admin_user, object_type, object_id, action, whenedited, user_id, reason, time_spent) FROM stdin;
1	Rob Crothall	problem	3	state_change	2016-12-23 06:07:36.248384	1		0
2	Rob Crothall	problem	2	state_change	2016-12-28 10:38:43.875926	1		0
3	Rob Crothall	problem	1	state_change	2016-12-28 10:40:07.971097	1		0
4	Rob Crothall	problem	2	state_change	2016-12-28 10:40:35.400078	1		0
\.


--
-- Name: admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('admin_log_id_seq', 4, true);


--
-- Data for Name: alert; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY alert (id, alert_type, parameter, parameter2, user_id, confirmed, lang, cobrand, cobrand_data, whensubscribed, whendisabled) FROM stdin;
1	new_updates	1	\N	1	1	en-gb	fixmystreets		2016-12-18 20:28:50.132072	\N
2	new_updates	2	\N	1	1	en-gb	fixmystreets		2016-12-18 21:04:47.609378	\N
3	new_updates	3	\N	1	1	en-gb	fixmystreets		2016-12-18 21:06:17.373323	\N
4	new_updates	6	\N	3	1	en-gb	fixmystreets		2016-12-28 11:02:07.037243	\N
5	new_updates	7	\N	3	1	en-gb	fixmystreets		2016-12-28 11:40:43.259154	\N
6	area_problems	639595	\N	1	1	en-gb	fixmystreets		2016-12-28 11:42:18.038578	\N
7	new_updates	8	\N	1	1	en-gb	fixmystreets		2016-12-28 11:48:07.607913	\N
8	new_updates	9	\N	1	1	en-gb	fixmystreets		2016-12-28 11:53:43.048948	\N
9	new_updates	10	\N	4	1	en-gb	fixmystreets		2016-12-28 12:03:23.991181	\N
\.


--
-- Name: alert_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('alert_id_seq', 9, true);


--
-- Data for Name: alert_sent; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY alert_sent (alert_id, parameter, whenqueued) FROM stdin;
\.


--
-- Data for Name: alert_type; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY alert_type (ref, head_sql_query, head_table, head_title, head_link, head_description, item_table, item_where, item_order, item_title, item_link, item_description, template) FROM stdin;
new_updates	select * from problem where id=?	problem	Updates on {{title}}	/	Updates on {{title}}	comment	comment.state='confirmed'	created desc	Update by {{name}}	/report/{{problem_id}}#comment_{{id}}	{{text}}	alert-update
new_problems			New problems on FixMyStreet	/	The latest problems reported by users	problem	problem.non_public = 'f' and problem.state in\n        ('confirmed', 'investigating', 'planned', 'in progress',\n         'fixed', 'fixed - council', 'fixed - user', 'closed'\n         'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n         'internal referral' )	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem
new_fixed_problems			Problems recently reported fixed on FixMyStreet	/	The latest problems reported fixed by users	problem	problem.non_public = 'f' and problem.state in ('fixed', 'fixed - user', 'fixed - council')	lastupdate desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem
local_problems			New local problems on FixMyStreet	/	The latest local problems reported by users	problem_find_nearby(?, ?, ?) as nearby,problem	nearby.problem_id = problem.id and problem.non_public = 'f' and problem.state in\n    ('confirmed', 'investigating', 'planned', 'in progress',\n     'fixed', 'fixed - council', 'fixed - user', 'closed',\n     'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n     'internal referral')	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-nearby
local_problems_state			New local problems on FixMyStreet	/	The latest local problems reported by users	problem_find_nearby(?, ?, ?) as nearby,problem	nearby.problem_id = problem.id and problem.non_public = 'f' and problem.state in (?)	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-nearby
postcode_local_problems			New problems near {{POSTCODE}} on FixMyStreet	/	The latest local problems reported by users	problem_find_nearby(?, ?, ?) as nearby,problem	nearby.problem_id = problem.id and problem.non_public = 'f' and problem.state in\n    ('confirmed', 'investigating', 'planned', 'in progress',\n     'fixed', 'fixed - council', 'fixed - user', 'closed',\n     'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n     'internal referral')	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-nearby
postcode_local_problems_state			New problems near {{POSTCODE}} on FixMyStreet	/	The latest local problems reported by users	problem_find_nearby(?, ?, ?) as nearby,problem	nearby.problem_id = problem.id and problem.non_public = 'f' and problem.state in (?)	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-nearby
council_problems			New problems to {{COUNCIL}} on FixMyStreet	/reports	The latest problems for {{COUNCIL}} reported by users	problem	problem.non_public = 'f' and problem.state in\n    ('confirmed', 'investigating', 'planned', 'in progress',\n      'fixed', 'fixed - council', 'fixed - user', 'closed',\n     'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n     'internal referral' ) AND\n    regexp_split_to_array(bodies_str, ',') && ARRAY[?]	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-council
ward_problems			New problems for {{COUNCIL}} within {{WARD}} ward on FixMyStreet	/reports	The latest problems for {{COUNCIL}} within {{WARD}} ward reported by users	problem	problem.non_public = 'f' and problem.state in\n    ('confirmed', 'investigating', 'planned', 'in progress',\n     'fixed', 'fixed - council', 'fixed - user', 'closed',\n     'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n     'internal referral' ) AND\n    (regexp_split_to_array(bodies_str, ',') && ARRAY[?] or bodies_str is null) and\n    areas like '%,'||?||',%'	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-ward
area_problems			New problems within {{NAME}}'s boundary on FixMyStreet	/reports	The latest problems within {{NAME}}'s boundary reported by users	problem	problem.non_public = 'f' and problem.state in\n    ('confirmed', 'investigating', 'planned', 'in progress',\n     'fixed', 'fixed - council', 'fixed - user', 'closed',\n     'action scheduled', 'not responsible', 'duplicate', 'unable to fix',\n     'internal referral' ) AND\n    areas like '%,'||?||',%'	created desc	{{title}}, {{confirmed}}	/report/{{id}}	{{detail}}	alert-problem-area
\.


--
-- Data for Name: body; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY body (id, name, external_url, parent, endpoint, jurisdiction, api_key, send_method, send_comments, comment_user_id, suppress_alerts, can_be_devolved, send_extended_statuses, deleted) FROM stdin;
1	Ndlambe District Municipality		\N					f	\N	f	f	f	f
\.


--
-- Data for Name: body_areas; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY body_areas (body_id, area_id) FROM stdin;
1	598484
\.


--
-- Name: body_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('body_id_seq', 1, true);


--
-- Data for Name: comment; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY comment (id, problem_id, user_id, anonymous, name, website, created, confirmed, text, photo, state, cobrand, lang, cobrand_data, mark_fixed, mark_open, problem_state, external_id, extra, send_fail_count, send_fail_reason, send_fail_timestamp, whensent) FROM stdin;
1	1	1	t	Rob Crothall	\N	2016-12-23 06:00:25.773004	2016-12-23 06:00:25.773004	Test fixed	\N	confirmed	fixmystreets	en-gb		t	f	fixed - user	\N	\N	0	\N	\N	\N
\.


--
-- Name: comment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('comment_id_seq', 1, true);


--
-- Data for Name: contact_response_priorities; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY contact_response_priorities (id, contact_id, response_priority_id) FROM stdin;
\.


--
-- Name: contact_response_priorities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('contact_response_priorities_id_seq', 1, false);


--
-- Data for Name: contact_response_templates; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY contact_response_templates (id, contact_id, response_template_id) FROM stdin;
\.


--
-- Name: contact_response_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('contact_response_templates_id_seq', 1, false);


--
-- Data for Name: contacts; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY contacts (id, body_id, category, email, confirmed, deleted, editor, whenedited, note, extra, non_public, endpoint, jurisdiction, api_key, send_method) FROM stdin;
1	1	Water leak	rob@robcrothall.co.za	t	f	0	2016-12-18 16:51:21.218181	Added Water Leak	A1:0,	f	\N	\N	\N	\N
2	1	Sewerage overflow	rob@robcrothall.co.za	t	f	0	2016-12-18 16:52:31.25816	Added Sewerage overflow	A1:0,	f	\N	\N	\N	\N
4	1	Litter and dumping	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:45:25.633153	Created Litter	A1:0,	f	\N	\N	\N	\N
5	1	Street Lights	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:46:09.222648	Created Street Lights	A1:0,	f	\N	\N	\N	\N
6	1	Potholes	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:46:47.029329	Created Potholes	A1:0,	f	\N	\N	\N	\N
7	1	Traffic Issues	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:47:38.68913	Created Traffic Issues	A1:0,	f	\N	\N	\N	\N
8	1	Storm water or River issues	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:53:54.768171	Create Storm Water	A1:0,	f	\N	\N	\N	\N
3	1	Graffiti	rob@robcrothall.co.za	t	t	Rob Crothall	2016-12-19 12:14:48.774912	Deleted	A1:0,	f	\N	\N	\N	\N
9	1	Social Grant visit required	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-19 13:28:24.531742	Created Social Grant	A1:0,	t	\N	\N	\N	\N
10	1	Indigent Visit required	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-19 13:30:23.756544	Created Indigent Visit	A1:0,	t	\N	\N	\N	\N
11	1	Road Issues	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:47:05.102761	Added Road Issues	A1:0,	f	\N	\N	\N	\N
12	1	Sewage - order Honeysucker	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:48:30.469809	Added ordering honeysucker	A1:0,	f	\N	\N	\N	\N
13	1	Water infrastructure	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:49:46.900046	Added Water infrastructure	A1:0,	f	\N	\N	\N	\N
14	1	Policies and Procedures	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:50:32.510529	Added Policies and procedures	A1:0,	f	\N	\N	\N	\N
15	1	Extended Public Works programme	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:51:13.208046	Added EPWP	A1:0,	f	\N	\N	\N	\N
16	1	Public Internet Access	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:51:54.397241	Added Internet access	A1:0,	f	\N	\N	\N	\N
17	1	Stray animals	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:52:39.697712	Added Stray animals	A1:0,	f	\N	\N	\N	\N
18	1	Sidewalk maintenance	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:53:41.424527	Added Sidewalk Maintenance	A1:0,	f	\N	\N	\N	\N
19	1	Other - please provide details	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:54:36.088511	Added Other	A1:0,	f	\N	\N	\N	\N
\.


--
-- Data for Name: contacts_history; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY contacts_history (contacts_history_id, contact_id, body_id, category, email, confirmed, deleted, editor, whenedited, note) FROM stdin;
1	1	1	Water leak	rob@robcrothall.co.za	t	f	0	2016-12-18 16:51:21.218181	Added Water Leak
2	2	1	Sewerage overflow	rob@robcrothall.co.za	t	f	0	2016-12-18 16:52:31.25816	Added Sewerage overflow
3	3	1	Graffiti	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:44:33.228333	Created Graffiti
4	4	1	Litter and dumping	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:45:25.633153	Created Litter
5	5	1	Street Lights	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:46:09.222648	Created Street Lights
6	6	1	Potholes	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:46:47.029329	Created Potholes
7	7	1	Traffic Issues	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:47:38.68913	Created Traffic Issues
8	8	1	Storm water or River issues	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-18 20:53:54.768171	Create Storm Water
9	3	1	Graffiti	rob@robcrothall.co.za	t	t	Rob Crothall	2016-12-19 12:14:48.774912	Deleted
10	9	1	Social Grant visit required	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-19 13:28:24.531742	Created Social Grant
11	10	1	Indigent Visit required	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-19 13:30:23.756544	Created Indigent Visit
12	11	1	Road Issues	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:47:05.102761	Added Road Issues
13	12	1	Sewage - order Honeysucker	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:48:30.469809	Added ordering honeysucker
14	13	1	Water infrastructure	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:49:46.900046	Added Water infrastructure
15	14	1	Policies and Procedures	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:50:32.510529	Added Policies and procedures
16	15	1	Extended Public Works programme	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:51:13.208046	Added EPWP
17	16	1	Public Internet Access	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:51:54.397241	Added Internet access
18	17	1	Stray animals	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:52:39.697712	Added Stray animals
19	18	1	Sidewalk maintenance	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:53:41.424527	Added Sidewalk Maintenance
20	19	1	Other - please provide details	rob@robcrothall.co.za	t	f	Rob Crothall	2016-12-28 10:54:36.088511	Added Other
\.


--
-- Name: contacts_history_contacts_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('contacts_history_contacts_history_id_seq', 20, true);


--
-- Name: contacts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('contacts_id_seq', 19, true);


--
-- Data for Name: flickr_imported; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY flickr_imported (id, problem_id) FROM stdin;
\.


--
-- Data for Name: moderation_original_data; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY moderation_original_data (id, problem_id, comment_id, title, detail, photo, anonymous, created) FROM stdin;
\.


--
-- Name: moderation_original_data_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('moderation_original_data_id_seq', 1, false);


--
-- Data for Name: partial_user; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY partial_user (id, service, nsid, name, email, phone) FROM stdin;
\.


--
-- Name: partial_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('partial_user_id_seq', 1, false);


--
-- Data for Name: problem; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY problem (id, postcode, latitude, longitude, bodies_str, bodies_missing, areas, category, title, detail, photo, used_map, user_id, name, anonymous, external_id, external_body, external_team, created, confirmed, state, lang, service, cobrand, cobrand_data, lastupdate, whensent, send_questionnaire, extra, flagged, geocode, response_priority_id, send_fail_count, send_fail_reason, send_fail_timestamp, send_method_used, non_public, external_source, external_source_id, interest_count, subcategory) FROM stdin;
10		-33.503300000000003	26.8246539999999989	1	\N	,598484,639599,657488,792786,795408,810665,	Extended Public Works programme	Need manpower to remove invasive plant species	At the AGM of the Bathurst Conservancy it was noted that more manpower is required to remove and control invasive plant species in Ndlambe. These include lantana, inkberry, and pereskia. See ToT page 4 dated 2016-12-22.	\N	t	4	Rob Knowles	t	\N	\N	\N	2016-12-28 12:03:23.976954	2016-12-28 12:03:23.976954	confirmed	en-gb		fixmystreets		2016-12-28 12:05:03.631924	2016-12-28 12:05:03.631924	t	\N	f	\N	\N	0	\N	\N	\N	f	\N	\N	0	\N
4		-33.5882289999999983	26.8858449999999998	1	\N	,598484,639600,792786,795408,810665,	Street Lights	Test 05	Explanation of Test 05	\N	t	2	Rob Crothall	f	\N	\N	\N	2016-12-19 09:18:32.540474	\N	unconfirmed	en-gb		fixmystreets		2016-12-19 09:18:32.540474	\N	t	\N	f	\N	\N	0	\N	\N	\N	f	\N	\N	0	\N
5		-33.5965220000000002	26.8803620000000016	1	\N	,598484,639595,792786,795408,810665,	Water leak	Test 06	Test 06 explanation	\N	t	2	Rob Crothall	f	\N	\N	\N	2016-12-19 09:33:50.514389	\N	unconfirmed	en-gb		fixmystreets		2016-12-19 09:33:50.514389	\N	t	\N	f	\N	\N	0	\N	\N	\N	f	\N	\N	0	\N
3		-28.8875509999999984	31.456671	1	\N	,596756,644038,792786,794761,810050,	Graffiti	Mjgf,jhf,jhg	Ljyrfljyfj	\N	t	1	Rob Crothall	t	\N	\N	\N	2016-12-18 21:06:17.360983	2016-12-18 21:06:17.360983	hidden	en-gb		fixmystreets		2016-12-23 06:07:36.253222	2016-12-18 21:10:08.040917	t	A1:3,T7:_fields,L1:0,T19:traffic_information,T0:,T20:detailed_information,T0:,	f	\N	\N	0	\N	\N	\N	f	\N	\N	0	\N
1		-33.5861329999999967	26.8848880000000001	1	\N	,598484,639600,792786,795408,810665,	Sewerage overflow	Test 03	Test 03 explanation	\N	t	1	Rob Crothall	t	\N	\N	\N	2016-12-18 20:28:50.109373	2016-12-18 20:28:50.109373	hidden	en-gb		fixmystreets		2016-12-28 10:40:07.975019	2016-12-18 20:30:06.52084	f	A1:3,T19:traffic_information,T0:,T7:_fields,L1:0,T20:detailed_information,T0:,	f	\N	\N	0	\N	\N	\N	f	\N	\N	0	\N
2	Weald Ave	-33.6121059999999972	26.8679249999999996	1	\N	,598484,639595,792786,795408,810665,	Sewerage overflow	Test 04	Test 04 explanation	\\x343265376132343036353734343361653732336634383365313766333034346235303331393765612e706e67	t	1	Rob Crothall	t	\N	\N	\N	2016-12-18 21:04:47.585455	2016-12-18 21:04:47.585455	hidden	en-gb		fixmystreets		2016-12-28 10:40:35.403443	2016-12-18 21:05:04.309727	t	A1:3,T20:detailed_information,T0:,T19:traffic_information,T0:,T7:_fields,L1:0,	f	\N	\N	0	\N	\N	\N	f	\N	\N	0	\N
6		-33.5052769999999995	26.8348580000000005	1	\N	,598484,639599,657488,792786,795408,810665,	Stray animals	Small herd of cows on R67 in Bathurst	Cows on the main road through Bathurst at 21h30 on 2016-12-25.	\N	t	3	Nola Johannsen	t	\N	\N	\N	2016-12-28 11:02:07.024842	2016-12-28 11:02:07.024842	confirmed	en-gb		fixmystreets		2016-12-28 11:05:05.551927	2016-12-28 11:05:05.551927	t	\N	f	\N	\N	0	\N	\N	\N	f	\N	\N	0	\N
7		-33.5666089999999997	26.8956310000000016	1	\N	,598484,639600,792786,795408,810665,	Stray animals	Stray cow beside R67 next to Nemato	Noted stray cow beside the R67 next to Nemato ate about 21h35 on 2016-12-25.	\N	t	3	Nola Johannsen	t	\N	\N	\N	2016-12-28 11:40:43.24665	2016-12-28 11:40:43.24665	confirmed	en-gb		fixmystreets		2016-12-28 11:45:04.201881	2016-12-28 11:45:04.201881	t	\N	f	\N	\N	0	\N	\N	\N	f	\N	\N	0	\N
8		-33.5963789999999989	26.8877430000000004	1	\N	,598484,639595,792786,795408,810665,	Litter and dumping	Litter collected early - Well done	Litter from the party on Christmas Day at The Krans was picked up and collected early the next day. Well done!	\N	t	1	Rob Crothall	f	\N	\N	\N	2016-12-28 11:48:07.598354	2016-12-28 11:48:07.598354	confirmed	en-gb		fixmystreets		2016-12-28 11:50:05.451882	2016-12-28 11:50:05.451882	t	\N	f	\N	\N	0	\N	\N	\N	f	\N	\N	0	\N
9		-33.5903380000000027	26.8852949999999993	1	\N	,598484,639595,792786,795408,810665,	Sewerage overflow	Sewage overflow in Van der Riet Street near My Pond	Sewage overflow near My Pond Hotel and Ocean Basket caused by inadequate sewerage infrastructure. See ToT page 3 for 2016-12-22.	\N	t	1	Rob Crothall	t	\N	\N	\N	2016-12-28 11:53:43.041221	2016-12-28 11:53:43.041221	confirmed	en-gb		fixmystreets		2016-12-28 11:55:03.942652	2016-12-28 11:55:03.942652	t	\N	f	\N	\N	0	\N	\N	\N	f	\N	\N	0	\N
\.


--
-- Name: problem_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('problem_id_seq', 10, true);


--
-- Data for Name: questionnaire; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY questionnaire (id, problem_id, whensent, whenanswered, ever_reported, old_state, new_state) FROM stdin;
1	1	2016-12-23 06:00:34.201294	2016-12-23 06:00:34.201294	f	confirmed	fixed - user
\.


--
-- Name: questionnaire_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('questionnaire_id_seq', 1, true);


--
-- Data for Name: response_priorities; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY response_priorities (id, body_id, deleted, name, description) FROM stdin;
\.


--
-- Name: response_priorities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('response_priorities_id_seq', 1, false);


--
-- Data for Name: response_templates; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY response_templates (id, body_id, title, text, created, auto_response) FROM stdin;
\.


--
-- Name: response_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('response_templates_id_seq', 1, false);


--
-- Data for Name: secret; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY secret (secret) FROM stdin;
e9897dd4b8cc7459262f6365f4d16fcf
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY sessions (id, session_data, expires) FROM stdin;
session:2e1c123f10ae65667419938efd132db6a6c2dba0                        	BQkDAAAABQoHZGVmYXVsdAAAAAxfX3VzZXJfcmVhbG0EAwAAAAAAAAAJb3ZlcnJpZGVzCVhXzuwA\nAAAJX19jcmVhdGVkCVhcvYIAAAAJX191cGRhdGVkBAMAAAABCIEAAAACaWQAAAAGX191c2Vy\n	1485357432
session:3d14503b21495500427f738c3178e12d08211069                        	BQkDAAAABQQDAAAAAQiBAAAAAmlkAAAABl9fdXNlcglYVrF6AAAACV9fY3JlYXRlZAlYVrF7AAAA\nCV9fdXBkYXRlZAQDAAAAAAAAAAlvdmVycmlkZXMKB2RlZmF1bHQAAAAMX191c2VyX3JlYWxt\n	1484514417
\.


--
-- Data for Name: textmystreet; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY textmystreet (name, email, postcode, mobile) FROM stdin;
\.


--
-- Data for Name: token; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY token (scope, token, data, created) FROM stdin;
problem	EfYktAEqsFJgFMWcti	\\x41313a352c54343a6e616d652c5431323a526f622043726f7468616c6c2c54383a70617373776f72642c5436303a2432612430382430754354642f73664966417764735067674d7046752e6d2f522e4a486c5150343048775763514b6f653350706131735377577278322c54353a70686f6e652c54303a2c54353a7469746c652c4e54323a69642c49313a342c	2016-12-19 09:18:32.548013
problem	E8Tj2qF5jsetC3WXwf	\\x41313a352c54323a69642c49313a352c54343a6e616d652c5431323a526f622043726f7468616c6c2c54383a70617373776f72642c54303a2c54353a70686f6e652c54303a2c54353a7469746c652c4e	2016-12-19 09:33:50.529395
email_sign_in	G6B9ndGdHZ6WFuLRq6	\\x41313a342c54383a70617373776f72642c5436303a24326124303824454b475430364d77567a34543043376e6c765978732e2f386130733544482f51366b4b6234443757534368676d3070542f4a3644792c54353a656d61696c2c5431343a6e6f6c6140656c6e2e636f2e7a612c54313a722c54323a6d792c54343a6e616d652c5431343a4e6f6c61204a6f68616e6e73656e2c	2016-12-27 12:19:53.064945
\.


--
-- Data for Name: user_body_permissions; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY user_body_permissions (id, user_id, body_id, permission_type) FROM stdin;
\.


--
-- Name: user_body_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('user_body_permissions_id_seq', 1, false);


--
-- Data for Name: user_planned_reports; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY user_planned_reports (id, user_id, report_id, added, removed) FROM stdin;
\.


--
-- Name: user_planned_reports_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('user_planned_reports_id_seq', 1, false);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: fms
--

COPY users (id, email, name, phone, password, from_body, flagged, is_superuser, title, twitter_id, facebook_id, area_id, extra) FROM stdin;
2	webmaster@zacs.co.za	\N	\N		\N	f	f	\N	\N	\N	\N	\N
3	nola@eln.co.za	Nola Johannsen			\N	f	f	\N	\N	\N	\N	\N
1	rob@crothall.co.za	Rob Crothall	0836785055	$2a$08$lXevRfLKzfPzqzMsAWbSluFIE5Hq6KkeAA95qc/5cQtroxU6gjUEq	\N	f	t	\N	\N	\N	\N	\N
4	robknowles69@gmail.com	Rob Knowles			\N	f	f	\N	\N	\N	\N	\N
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: fms
--

SELECT pg_catalog.setval('users_id_seq', 4, true);


--
-- Name: abuse_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY abuse
    ADD CONSTRAINT abuse_pkey PRIMARY KEY (email);


--
-- Name: admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY admin_log
    ADD CONSTRAINT admin_log_pkey PRIMARY KEY (id);


--
-- Name: alert_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY alert
    ADD CONSTRAINT alert_pkey PRIMARY KEY (id);


--
-- Name: alert_type_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY alert_type
    ADD CONSTRAINT alert_type_pkey PRIMARY KEY (ref);


--
-- Name: body_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY body
    ADD CONSTRAINT body_pkey PRIMARY KEY (id);


--
-- Name: comment_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY comment
    ADD CONSTRAINT comment_pkey PRIMARY KEY (id);


--
-- Name: contact_response_priorities_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY contact_response_priorities
    ADD CONSTRAINT contact_response_priorities_pkey PRIMARY KEY (id);


--
-- Name: contact_response_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY contact_response_templates
    ADD CONSTRAINT contact_response_templates_pkey PRIMARY KEY (id);


--
-- Name: contacts_history_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY contacts_history
    ADD CONSTRAINT contacts_history_pkey PRIMARY KEY (contacts_history_id);


--
-- Name: contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (id);


--
-- Name: moderation_original_data_comment_id_key; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY moderation_original_data
    ADD CONSTRAINT moderation_original_data_comment_id_key UNIQUE (comment_id);


--
-- Name: moderation_original_data_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY moderation_original_data
    ADD CONSTRAINT moderation_original_data_pkey PRIMARY KEY (id);


--
-- Name: partial_user_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY partial_user
    ADD CONSTRAINT partial_user_pkey PRIMARY KEY (id);


--
-- Name: problem_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY problem
    ADD CONSTRAINT problem_pkey PRIMARY KEY (id);


--
-- Name: questionnaire_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY questionnaire
    ADD CONSTRAINT questionnaire_pkey PRIMARY KEY (id);


--
-- Name: response_priorities_body_id_name_key; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY response_priorities
    ADD CONSTRAINT response_priorities_body_id_name_key UNIQUE (body_id, name);


--
-- Name: response_priorities_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY response_priorities
    ADD CONSTRAINT response_priorities_pkey PRIMARY KEY (id);


--
-- Name: response_templates_body_id_title_key; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY response_templates
    ADD CONSTRAINT response_templates_body_id_title_key UNIQUE (body_id, title);


--
-- Name: response_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY response_templates
    ADD CONSTRAINT response_templates_pkey PRIMARY KEY (id);


--
-- Name: sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: token_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY token
    ADD CONSTRAINT token_pkey PRIMARY KEY (scope, token);


--
-- Name: user_body_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY user_body_permissions
    ADD CONSTRAINT user_body_permissions_pkey PRIMARY KEY (id);


--
-- Name: user_body_permissions_user_id_body_id_permission_type_key; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY user_body_permissions
    ADD CONSTRAINT user_body_permissions_user_id_body_id_permission_type_key UNIQUE (user_id, body_id, permission_type);


--
-- Name: user_planned_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY user_planned_reports
    ADD CONSTRAINT user_planned_reports_pkey PRIMARY KEY (id);


--
-- Name: users_email_key; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users_facebook_id_key; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_facebook_id_key UNIQUE (facebook_id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_twitter_id_key; Type: CONSTRAINT; Schema: public; Owner: fms; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_twitter_id_key UNIQUE (twitter_id);


--
-- Name: alert_alert_type_confirmed_whendisabled_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX alert_alert_type_confirmed_whendisabled_idx ON alert USING btree (alert_type, confirmed, whendisabled);


--
-- Name: alert_sent_alert_id_parameter_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX alert_sent_alert_id_parameter_idx ON alert_sent USING btree (alert_id, parameter);


--
-- Name: alert_user_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX alert_user_id_idx ON alert USING btree (user_id);


--
-- Name: alert_whendisabled_cobrand_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX alert_whendisabled_cobrand_idx ON alert USING btree (whendisabled, cobrand);


--
-- Name: alert_whensubscribed_confirmed_cobrand_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX alert_whensubscribed_confirmed_cobrand_idx ON alert USING btree (whensubscribed, confirmed, cobrand);


--
-- Name: body_areas_body_id_area_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE UNIQUE INDEX body_areas_body_id_area_id_idx ON body_areas USING btree (body_id, area_id);


--
-- Name: comment_problem_id_created_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX comment_problem_id_created_idx ON comment USING btree (problem_id, created);


--
-- Name: comment_problem_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX comment_problem_id_idx ON comment USING btree (problem_id);


--
-- Name: comment_user_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX comment_user_id_idx ON comment USING btree (user_id);


--
-- Name: contacts_body_id_category_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE UNIQUE INDEX contacts_body_id_category_idx ON contacts USING btree (body_id, category);


--
-- Name: flickr_imported_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE UNIQUE INDEX flickr_imported_id_idx ON flickr_imported USING btree (id);


--
-- Name: partial_user_service_email_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX partial_user_service_email_idx ON partial_user USING btree (service, email);


--
-- Name: problem_bodies_str_array_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX problem_bodies_str_array_idx ON problem USING gin (regexp_split_to_array(bodies_str, ','::text));


--
-- Name: problem_external_body_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX problem_external_body_idx ON problem USING btree (lower(external_body));


--
-- Name: problem_radians_latitude_longitude_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX problem_radians_latitude_longitude_idx ON problem USING btree (radians(latitude), radians(longitude));


--
-- Name: problem_state_latitude_longitude_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX problem_state_latitude_longitude_idx ON problem USING btree (state, latitude, longitude);


--
-- Name: problem_user_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX problem_user_id_idx ON problem USING btree (user_id);


--
-- Name: questionnaire_problem_id_idx; Type: INDEX; Schema: public; Owner: fms; Tablespace: 
--

CREATE INDEX questionnaire_problem_id_idx ON questionnaire USING btree (problem_id);


--
-- Name: contacts_insert_trigger; Type: TRIGGER; Schema: public; Owner: fms
--

CREATE TRIGGER contacts_insert_trigger AFTER INSERT ON contacts FOR EACH ROW EXECUTE PROCEDURE contacts_updated();


--
-- Name: contacts_update_trigger; Type: TRIGGER; Schema: public; Owner: fms
--

CREATE TRIGGER contacts_update_trigger AFTER UPDATE ON contacts FOR EACH ROW EXECUTE PROCEDURE contacts_updated();


--
-- Name: admin_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY admin_log
    ADD CONSTRAINT admin_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: alert_alert_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY alert
    ADD CONSTRAINT alert_alert_type_fkey FOREIGN KEY (alert_type) REFERENCES alert_type(ref);


--
-- Name: alert_sent_alert_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY alert_sent
    ADD CONSTRAINT alert_sent_alert_id_fkey FOREIGN KEY (alert_id) REFERENCES alert(id);


--
-- Name: alert_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY alert
    ADD CONSTRAINT alert_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: body_areas_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY body_areas
    ADD CONSTRAINT body_areas_body_id_fkey FOREIGN KEY (body_id) REFERENCES body(id);


--
-- Name: body_comment_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY body
    ADD CONSTRAINT body_comment_user_id_fkey FOREIGN KEY (comment_user_id) REFERENCES users(id);


--
-- Name: body_parent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY body
    ADD CONSTRAINT body_parent_fkey FOREIGN KEY (parent) REFERENCES body(id);


--
-- Name: comment_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY comment
    ADD CONSTRAINT comment_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES problem(id);


--
-- Name: comment_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY comment
    ADD CONSTRAINT comment_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: contact_response_priorities_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contact_response_priorities
    ADD CONSTRAINT contact_response_priorities_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id);


--
-- Name: contact_response_priorities_response_priority_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contact_response_priorities
    ADD CONSTRAINT contact_response_priorities_response_priority_id_fkey FOREIGN KEY (response_priority_id) REFERENCES response_priorities(id);


--
-- Name: contact_response_templates_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contact_response_templates
    ADD CONSTRAINT contact_response_templates_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES contacts(id);


--
-- Name: contact_response_templates_response_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contact_response_templates
    ADD CONSTRAINT contact_response_templates_response_template_id_fkey FOREIGN KEY (response_template_id) REFERENCES response_templates(id);


--
-- Name: contacts_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY contacts
    ADD CONSTRAINT contacts_body_id_fkey FOREIGN KEY (body_id) REFERENCES body(id);


--
-- Name: flickr_imported_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY flickr_imported
    ADD CONSTRAINT flickr_imported_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES problem(id);


--
-- Name: moderation_original_data_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY moderation_original_data
    ADD CONSTRAINT moderation_original_data_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES comment(id) ON DELETE CASCADE;


--
-- Name: moderation_original_data_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY moderation_original_data
    ADD CONSTRAINT moderation_original_data_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES problem(id) ON DELETE CASCADE;


--
-- Name: problem_response_priority_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY problem
    ADD CONSTRAINT problem_response_priority_id_fkey FOREIGN KEY (response_priority_id) REFERENCES response_priorities(id);


--
-- Name: problem_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY problem
    ADD CONSTRAINT problem_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: questionnaire_problem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY questionnaire
    ADD CONSTRAINT questionnaire_problem_id_fkey FOREIGN KEY (problem_id) REFERENCES problem(id);


--
-- Name: response_priorities_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY response_priorities
    ADD CONSTRAINT response_priorities_body_id_fkey FOREIGN KEY (body_id) REFERENCES body(id);


--
-- Name: response_templates_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY response_templates
    ADD CONSTRAINT response_templates_body_id_fkey FOREIGN KEY (body_id) REFERENCES body(id);


--
-- Name: user_body_permissions_body_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY user_body_permissions
    ADD CONSTRAINT user_body_permissions_body_id_fkey FOREIGN KEY (body_id) REFERENCES body(id);


--
-- Name: user_body_permissions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY user_body_permissions
    ADD CONSTRAINT user_body_permissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: user_planned_reports_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY user_planned_reports
    ADD CONSTRAINT user_planned_reports_report_id_fkey FOREIGN KEY (report_id) REFERENCES problem(id);


--
-- Name: user_planned_reports_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY user_planned_reports
    ADD CONSTRAINT user_planned_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: users_from_body_fkey; Type: FK CONSTRAINT; Schema: public; Owner: fms
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_from_body_fkey FOREIGN KEY (from_body) REFERENCES body(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

