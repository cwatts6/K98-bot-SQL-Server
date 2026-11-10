-- Observed dependency definition, not a migration or a live sequence reset.
-- Existing databases must retain their current value; see docs/p02-d4b-installed-dependencies.md.
CREATE SEQUENCE [dbo].[KS4_UNO_SEQ]
    AS int
    START WITH 130489
    INCREMENT BY 1
    MINVALUE -2147483648
    MAXVALUE 2147483647
    NO CYCLE
    NO CACHE;
