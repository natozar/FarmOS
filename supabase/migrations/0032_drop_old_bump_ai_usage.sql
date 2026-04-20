-- 0032: remove sobrecarga antiga de bump_ai_usage(uuid, text, int)
-- =================================================================
-- 0030 criou a v1 com 3 args. 0031 criou a v2 com 5 args (com defaults).
-- Postgres mantem ambas — e reclama "is not unique" quando o client
-- chama `bump_ai_usage(uuid, unknown, int)` porque `unknown` da match
-- em ambas as sinaturas. Droppa a v1 pra deixar so a v2 com defaults.

DROP FUNCTION IF EXISTS public.bump_ai_usage(uuid, text, integer);
