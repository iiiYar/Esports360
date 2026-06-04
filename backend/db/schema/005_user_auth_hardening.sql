ALTER TABLE app_users
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS hashed_password TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_app_users_email_unique
ON app_users(lower(email))
WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_app_users_email
ON app_users(lower(email))
WHERE email IS NOT NULL;
