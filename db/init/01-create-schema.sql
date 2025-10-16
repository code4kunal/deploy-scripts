-- VayunX Discovery Service - Database Initialization Script
-- This script creates all required tables and indexes

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create CBOM Results Table
CREATE TABLE IF NOT EXISTS cbom_results (
    job_id VARCHAR(255) PRIMARY KEY,
    file_name VARCHAR(500),
    cbom JSONB,
    detected_assets JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',
    error_message TEXT,
    is_cancelled BOOLEAN DEFAULT FALSE,
    bom_type VARCHAR(20) DEFAULT 'cbom',
    analysis_type VARCHAR(50),
    progress_percentage INTEGER DEFAULT 0,
    current_phase VARCHAR(100) DEFAULT 'Upload',
    current_step VARCHAR(200),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    estimated_completion TIMESTAMP WITH TIME ZONE,
    elapsed_time INTEGER DEFAULT 0,
    queue_position INTEGER,
    processing_speed NUMERIC(10, 2),
    error_code VARCHAR(50),
    detailed_error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    priority INTEGER DEFAULT 0,
    resource_usage JSONB,
    job_logs TEXT,
    submitted_by VARCHAR(255),
    job_config JSONB,
    result_metadata JSONB
);

-- Create indexes for CBOM Results
CREATE INDEX IF NOT EXISTS idx_cbom_results_status ON cbom_results(status);
CREATE INDEX IF NOT EXISTS idx_cbom_results_created_at ON cbom_results(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cbom_results_analysis_type ON cbom_results(analysis_type);
CREATE INDEX IF NOT EXISTS idx_cbom_results_bom_type ON cbom_results(bom_type);
CREATE INDEX IF NOT EXISTS idx_cbom_results_priority ON cbom_results(priority DESC);

-- Create Crypto Asset Master Table (Single Source of Truth)
CREATE TABLE IF NOT EXISTS crypto_asset_master (
    id SERIAL PRIMARY KEY,
    asset_name VARCHAR(255) UNIQUE NOT NULL,
    normalized_name VARCHAR(255) UNIQUE NOT NULL,
    asset_type VARCHAR(100),
    primitive VARCHAR(100),
    functions VARCHAR(500),
    source_of_truth VARCHAR(200),
    nist_compliant VARCHAR(50),
    pqc_compliant VARCHAR(50),
    pqc_algorithm VARCHAR(100),
    shelf_life_status VARCHAR(50),
    shelf_life_expiry VARCHAR(100),
    severity VARCHAR(20),
    explanation TEXT,
    shors_algorithm VARCHAR(50),
    grovers_algorithm VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for Crypto Asset Master
CREATE INDEX IF NOT EXISTS idx_crypto_asset_normalized ON crypto_asset_master(normalized_name);
CREATE INDEX IF NOT EXISTS idx_crypto_asset_type ON crypto_asset_master(asset_type);
CREATE INDEX IF NOT EXISTS idx_crypto_asset_primitive ON crypto_asset_master(primitive);
CREATE INDEX IF NOT EXISTS idx_crypto_asset_nist ON crypto_asset_master(nist_compliant);
CREATE INDEX IF NOT EXISTS idx_crypto_asset_pqc ON crypto_asset_master(pqc_compliant);

-- Create Job Progress Steps Table
CREATE TABLE IF NOT EXISTS job_progress_steps (
    id SERIAL PRIMARY KEY,
    job_id VARCHAR(255) NOT NULL REFERENCES cbom_results(job_id) ON DELETE CASCADE,
    step_name VARCHAR(200) NOT NULL,
    step_description TEXT,
    phase VARCHAR(100),
    status VARCHAR(50) DEFAULT 'pending',
    progress_percentage INTEGER DEFAULT 0,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    step_order INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(job_id, step_name)
);

-- Create index for Job Progress Steps
CREATE INDEX IF NOT EXISTS idx_job_progress_job_id ON job_progress_steps(job_id);
CREATE INDEX IF NOT EXISTS idx_job_progress_status ON job_progress_steps(status);

-- Create Job Events Table (for audit trail)
CREATE TABLE IF NOT EXISTS job_events (
    id SERIAL PRIMARY KEY,
    job_id VARCHAR(255) NOT NULL REFERENCES cbom_results(job_id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    event_message TEXT,
    event_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index for Job Events
CREATE INDEX IF NOT EXISTS idx_job_events_job_id ON job_events(job_id);
CREATE INDEX IF NOT EXISTS idx_job_events_created_at ON job_events(created_at DESC);

-- Create NIST Compliance Cache Table
CREATE TABLE IF NOT EXISTS nist_compliance_cache (
    id SERIAL PRIMARY KEY,
    algorithm VARCHAR(255) UNIQUE NOT NULL,
    is_compliant BOOLEAN NOT NULL,
    compliance_data JSONB,
    cached_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Create index for NIST Cache
CREATE INDEX IF NOT EXISTS idx_nist_cache_algorithm ON nist_compliance_cache(algorithm);
CREATE INDEX IF NOT EXISTS idx_nist_cache_expires ON nist_compliance_cache(expires_at);

-- Create Asset Summaries Table
CREATE TABLE IF NOT EXISTS asset_summaries (
    id SERIAL PRIMARY KEY,
    job_id VARCHAR(255) NOT NULL REFERENCES cbom_results(job_id) ON DELETE CASCADE,
    asset_name VARCHAR(255) NOT NULL,
    asset_type VARCHAR(100),
    primitive VARCHAR(100),
    occurrences INTEGER DEFAULT 1,
    confidence NUMERIC(5, 2),
    nist_compliant BOOLEAN,
    pqc_compliant BOOLEAN,
    severity VARCHAR(20),
    locations JSONB,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for Asset Summaries
CREATE INDEX IF NOT EXISTS idx_asset_summaries_job_id ON asset_summaries(job_id);
CREATE INDEX IF NOT EXISTS idx_asset_summaries_asset_name ON asset_summaries(asset_name);
CREATE INDEX IF NOT EXISTS idx_asset_summaries_primitive ON asset_summaries(primitive);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for crypto_asset_master
CREATE TRIGGER update_crypto_asset_master_updated_at
    BEFORE UPDATE ON crypto_asset_master
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for job_progress_steps
CREATE TRIGGER update_job_progress_steps_updated_at
    BEFORE UPDATE ON job_progress_steps
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO vayunx_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO vayunx_user;

-- Log completion
DO $$
BEGIN
    RAISE NOTICE 'VayunX Discovery Service database schema created successfully!';
END $$;
