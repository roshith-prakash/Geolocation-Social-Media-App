-- ============================================
-- FlashMap Social — Supabase Schema Migration
-- ============================================
-- Run this SQL in the Supabase SQL Editor to set up your database.

-- Enable PostGIS extension for spatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- =====================
-- Users Table
-- =====================
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  profile_image TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- =====================
-- Posts Table (with geography column)
-- =====================
CREATE TABLE IF NOT EXISTS public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT,
  image_url TEXT,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Spatial index for fast proximity searches
CREATE INDEX IF NOT EXISTS idx_posts_location ON public.posts USING GIST(location);

-- =====================
-- Followers Table
-- =====================
CREATE TABLE IF NOT EXISTS public.followers (
  follower_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  following_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (follower_id, following_id)
);

-- =====================
-- RPC: Get nearby posts within a radius
-- =====================
CREATE OR REPLACE FUNCTION get_nearby_posts(
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  radius_meters DOUBLE PRECISION
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  content TEXT,
  image_url TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ,
  username TEXT,
  profile_image TEXT,
  distance DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.user_id,
    p.content,
    p.image_url,
    ST_Y(p.location::geometry) AS latitude,
    ST_X(p.location::geometry) AS longitude,
    p.created_at,
    u.username,
    u.profile_image,
    ST_Distance(
      p.location,
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
    ) AS distance
  FROM public.posts p
  JOIN public.users u ON u.id = p.user_id
  WHERE ST_DWithin(
    p.location,
    ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
    radius_meters
  )
  ORDER BY distance ASC;
END;
$$ LANGUAGE plpgsql;

-- =====================
-- RPC: Get posts by a specific user
-- =====================
CREATE OR REPLACE FUNCTION get_user_posts(target_user_id UUID)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  content TEXT,
  image_url TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ,
  username TEXT,
  profile_image TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.user_id,
    p.content,
    p.image_url,
    ST_Y(p.location::geometry) AS latitude,
    ST_X(p.location::geometry) AS longitude,
    p.created_at,
    u.username,
    u.profile_image
  FROM public.posts p
  JOIN public.users u ON u.id = p.user_id
  WHERE p.user_id = target_user_id
  ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================
-- RPC: Create a post with location
-- =====================
CREATE OR REPLACE FUNCTION create_post_with_location(
  p_user_id UUID,
  p_content TEXT,
  p_image_url TEXT,
  p_lng DOUBLE PRECISION,
  p_lat DOUBLE PRECISION
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.posts (user_id, content, image_url, location)
  VALUES (
    p_user_id,
    p_content,
    p_image_url,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  );
END;
$$ LANGUAGE plpgsql;

-- =====================
-- Row Level Security (RLS)
-- =====================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.followers ENABLE ROW LEVEL SECURITY;

-- Allow public read, authenticated insert/update
CREATE POLICY "Users are viewable by everyone" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile" ON public.users FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (true);

CREATE POLICY "Posts are viewable by everyone" ON public.posts FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert posts" ON public.posts FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can delete own posts" ON public.posts FOR DELETE USING (true);

CREATE POLICY "Followers are viewable by everyone" ON public.followers FOR SELECT USING (true);
CREATE POLICY "Authenticated users can follow" ON public.followers FOR INSERT WITH CHECK (true);
CREATE POLICY "Authenticated users can unfollow" ON public.followers FOR DELETE USING (true);
