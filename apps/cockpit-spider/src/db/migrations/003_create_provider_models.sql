CREATE TABLE IF NOT EXISTS provider_models (
    id SERIAL PRIMARY KEY,
    provider_id INTEGER NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    model_name VARCHAR(180) NOT NULL,
    model_id VARCHAR(220) NOT NULL,
    context_window INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_provider_models_provider_model_id UNIQUE (provider_id, model_id)
);
