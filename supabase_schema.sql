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
-- Post Likes Table
-- =====================
CREATE TABLE IF NOT EXISTS public.post_likes (
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

-- =====================
-- Comments Table
-- =====================
CREATE TABLE IF NOT EXISTS public.comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comments_post_id ON public.comments(post_id);

-- =====================
-- RPC: Get comments for a post
-- =====================
CREATE OR REPLACE FUNCTION get_comments(target_post_id UUID)
RETURNS TABLE (
  id UUID,
  post_id UUID,
  user_id UUID,
  content TEXT,
  created_at TIMESTAMPTZ,
  username TEXT,
  profile_image TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.post_id,
    c.user_id,
    c.content,
    c.created_at,
    u.username,
    u.profile_image
  FROM public.comments c
  JOIN public.users u ON u.id = c.user_id
  WHERE c.post_id = target_post_id
  ORDER BY c.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- =====================
-- RPC: Get nearby posts within a radius
-- =====================
DROP FUNCTION IF EXISTS get_nearby_posts(double precision, double precision, double precision);
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
  distance DOUBLE PRECISION,
  like_count BIGINT
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
    ) AS distance,
    COUNT(pl.user_id) AS like_count
  FROM public.posts p
  JOIN public.users u ON u.id = p.user_id
  LEFT JOIN public.post_likes pl ON pl.post_id = p.id
  WHERE ST_DWithin(
    p.location,
    ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
    radius_meters
  )
  GROUP BY p.id, u.username, u.profile_image
  ORDER BY distance ASC;
END;
$$ LANGUAGE plpgsql;

-- =====================
-- RPC: Get posts by a specific user
-- =====================
DROP FUNCTION IF EXISTS get_user_posts(uuid);
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
  profile_image TEXT,
  like_count BIGINT
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
    COUNT(pl.user_id) AS like_count
  FROM public.posts p
  JOIN public.users u ON u.id = p.user_id
  LEFT JOIN public.post_likes pl ON pl.post_id = p.id
  WHERE p.user_id = target_user_id
  GROUP BY p.id, u.username, u.profile_image
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

-- Users policies
DROP POLICY IF EXISTS "Users are viewable by everyone" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users are viewable by everyone" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile" ON public.users FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (true);

-- Posts policies
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON public.posts;
DROP POLICY IF EXISTS "Authenticated users can insert posts" ON public.posts;
DROP POLICY IF EXISTS "Users can delete own posts" ON public.posts;
CREATE POLICY "Posts are viewable by everyone" ON public.posts FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert posts" ON public.posts FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can delete own posts" ON public.posts FOR DELETE USING (true);

-- Followers policies
DROP POLICY IF EXISTS "Followers are viewable by everyone" ON public.followers;
DROP POLICY IF EXISTS "Authenticated users can follow" ON public.followers;
DROP POLICY IF EXISTS "Authenticated users can unfollow" ON public.followers;
CREATE POLICY "Followers are viewable by everyone" ON public.followers FOR SELECT USING (true);
CREATE POLICY "Authenticated users can follow" ON public.followers FOR INSERT WITH CHECK (true);
CREATE POLICY "Authenticated users can unfollow" ON public.followers FOR DELETE USING (true);

-- Post likes policies
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Likes are viewable by everyone" ON public.post_likes;
DROP POLICY IF EXISTS "Authenticated users can like" ON public.post_likes;
DROP POLICY IF EXISTS "Authenticated users can unlike" ON public.post_likes;
CREATE POLICY "Likes are viewable by everyone" ON public.post_likes FOR SELECT USING (true);
CREATE POLICY "Authenticated users can like" ON public.post_likes FOR INSERT WITH CHECK (true);
CREATE POLICY "Authenticated users can unlike" ON public.post_likes FOR DELETE USING (true);

-- Comments policies
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Comments are viewable by everyone" ON public.comments;
DROP POLICY IF EXISTS "Authenticated users can comment" ON public.comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON public.comments;
CREATE POLICY "Comments are viewable by everyone" ON public.comments FOR SELECT USING (true);
CREATE POLICY "Authenticated users can comment" ON public.comments FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can delete own comments" ON public.comments FOR DELETE USING (true);
