-- Migration: Create app_config table for force update mechanism
-- Run this in your Supabase SQL Editor

-- Create app_config table
CREATE TABLE IF NOT EXISTS public.app_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read app_config (needed for force update check from mobile app)
CREATE POLICY "app_config_select"
    ON public.app_config
    FOR SELECT
    USING (true);

-- Allow only admins to insert
CREATE POLICY "app_config_admin_insert"
    ON public.app_config FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role = 'admin'
        )
    );

-- Allow only admins to update
CREATE POLICY "app_config_admin_update"
    ON public.app_config FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role = 'admin'
        )
    );

-- Allow only admins to delete
CREATE POLICY "app_config_admin_delete"
    ON public.app_config FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role = 'admin'
        )
    );

-- Insert initial version config
INSERT INTO public.app_config (key, value) VALUES (
    'version_control',
    '{
        "min_version_android": "1.0.0",
        "min_version_ios": "1.0.0",
        "latest_version_android": "1.0.0",
        "latest_version_ios": "1.0.0",
        "force_update": false,
        "update_message_en": "A new version is available. Please update to continue.",
        "update_message_he": "גרסה חדשה זמינה. אנא עדכן כדי להמשיך.",
        "play_store_url": "https://play.google.com/store/apps/details?id=com.chessshare.app",
        "app_store_url": "https://apps.apple.com/app/id000000000"
    }'::jsonb
) ON CONFLICT (key) DO NOTHING;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to auto-update updated_at
DROP TRIGGER IF EXISTS update_app_config_updated_at ON public.app_config;
CREATE TRIGGER update_app_config_updated_at
    BEFORE UPDATE ON public.app_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions (read for all, write handled by RLS)
GRANT SELECT ON public.app_config TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_config TO authenticated;
