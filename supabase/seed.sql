-- CookQuest Seed Data
-- Run this AFTER schema.sql in the Supabase SQL Editor

-- ============================================================
-- TECHNIQUES
-- ============================================================

INSERT INTO techniques (name, category, difficulty_tier, xp_reward) VALUES
  -- Knife Skills
  ('Dice',                        'knife_skills', 'beginner',     10),
  ('Julienne',                    'knife_skills', 'intermediate', 15),
  ('Chiffonade',                  'knife_skills', 'intermediate', 15),
  ('Brunoise',                    'knife_skills', 'advanced',     20),

  -- Heat Control
  ('Sauté',                       'heat_control', 'beginner',     10),
  ('Stir-fry',                    'heat_control', 'beginner',     10),
  ('Pan-sear',                    'heat_control', 'beginner',     10),
  ('Simmer',                      'heat_control', 'beginner',     10),
  ('Blanch',                      'heat_control', 'intermediate', 15),
  ('Deglaze',                     'heat_control', 'intermediate', 20),
  ('Flambé',                      'heat_control', 'advanced',     30),
  ('Deep-fry',                    'heat_control', 'intermediate', 15),

  -- Sauces & Emulsification
  ('Make a roux',                 'sauces',       'intermediate', 20),
  ('Emulsify (vinaigrette)',       'sauces',       'beginner',     10),
  ('Hollandaise',                  'sauces',       'advanced',     30),
  ('Reduction',                    'sauces',       'intermediate', 15),

  -- Baking
  ('Cream butter and sugar',       'baking',       'beginner',     10),
  ('Fold batter',                  'baking',       'beginner',     10),
  ('Laminate dough',               'baking',       'advanced',     30),
  ('Temper chocolate',             'baking',       'advanced',     30),

  -- Prep
  ('Marinate',                     'prep',         'beginner',     10),
  ('Brine',                        'prep',         'intermediate', 15),
  ('Butcher / break down chicken', 'prep',         'intermediate', 20),
  ('Make stock',                   'prep',         'intermediate', 20)

ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- BADGES
-- ============================================================

INSERT INTO badges (name, description, icon, unlock_condition_type, unlock_condition_value, unlock_condition_extra) VALUES
  ('First Flame',       'Log your very first cooking session',   '🔥', 'session_count',   1,   NULL),
  ('On a Roll',         'Cook 5 days in a row',                  '📅', 'streak',           5,   NULL),
  ('Week Warrior',      'Maintain a 7-day cooking streak',       '⚔️', 'streak',           7,   NULL),
  ('Technique Rookie',  'Use 5 different techniques',            '🥄', 'technique_count',  5,   NULL),
  ('Technique Veteran', 'Use 15 different techniques',           '👨‍🍳', 'technique_count', 15,   NULL),
  ('Technique Master',  'Use all 25 techniques at least once',   '🏆', 'technique_count',  25,  NULL),
  ('World Traveller',   'Cook dishes from 5 different cuisines', '🌍', 'cuisine_count',    5,   NULL),
  ('Century Cook',      'Log 100 cooking sessions',              '💯', 'session_count',    100, NULL),
  ('Rising Star',       'Reach 1000 XP',                        '⭐', 'xp',               1000, NULL),
  ('Fire Starter',      'Use the Flambé technique',              '🔥', 'specific_technique', 1, 'Flambé'),
  ('Sauce Boss',        'Master all sauce techniques',           '🫕', 'technique_count',  4,   'sauces')

ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- SAMPLE RECIPES (optional — adds browse content from day 1)
-- ============================================================

INSERT INTO recipes (name, cuisine_type, difficulty, estimated_time_mins, description, instructions) VALUES
  (
    'Classic French Omelette',
    'western', 'beginner', 15,
    'A silky, rolled omelette — the benchmark of heat control.',
    E'1. Crack 3 eggs into a bowl, whisk with a pinch of salt.\n2. Heat a non-stick pan over medium-high; add 15g butter.\n3. When foam subsides, pour in eggs. Stir continuously with a spatula.\n4. Before fully set, fold and roll onto a plate. Should be pale yellow with no colour.'
  ),
  (
    'Beef Stir-fry with Ginger & Spring Onion',
    'asian', 'beginner', 20,
    'Fast, high-heat wok cooking that builds stir-fry fundamentals.',
    E'1. Slice 300g beef thinly across the grain; marinate 10 min in soy, sesame oil, cornstarch.\n2. Heat wok until smoking. Add oil.\n3. Stir-fry beef in a single layer 1–2 min. Remove.\n4. Add ginger julienne and spring onion. Toss 30 sec.\n5. Return beef, add sauce (oyster sauce + stock), toss to coat.'
  ),
  (
    'Chicken Stock',
    'western', 'intermediate', 180,
    'The foundation of professional cooking — patience and technique.',
    E'1. Roast carcass + vegetables at 200°C for 30 min.\n2. Place in large pot, cover with cold water.\n3. Bring to a bare simmer (never boil). Skim scum.\n4. Add bouquet garni. Simmer 3 hours uncovered.\n5. Strain through fine sieve. Cool rapidly over ice bath.'
  ),
  (
    'Hollandaise Sauce',
    'western', 'advanced', 25,
    'Classic emulsified butter sauce — tests patience and temperature control.',
    E'1. Reduce white wine vinegar with peppercorns to 2 tbsp. Cool.\n2. Whisk 3 egg yolks with reduction in a bain-marie until thick ribbons form.\n3. Slowly drizzle in 200g clarified butter while whisking constantly.\n4. Season with lemon juice and salt. Keep warm at 60°C.'
  ),
  (
    'Chicken Tagine',
    'middle_eastern', 'intermediate', 90,
    'Slow-braised North African stew that builds layered flavour.',
    E'1. Brown marinated chicken pieces in oil. Set aside.\n2. Sauté onion until soft. Add spices (cumin, coriander, ginger, turmeric).\n3. Return chicken. Add stock, preserved lemon, olives.\n4. Simmer covered 45 min until tender.\n5. Garnish with fresh coriander and serve with couscous.'
  )

ON CONFLICT DO NOTHING;

-- Link recipes to their techniques
WITH t AS (SELECT id, name FROM techniques)
INSERT INTO recipe_techniques (recipe_id, technique_id)
SELECT r.id, t.id
FROM recipes r, t
WHERE
  (r.name = 'Classic French Omelette'            AND t.name IN ('Pan-sear', 'Simmer'))
  OR (r.name = 'Beef Stir-fry with Ginger & Spring Onion' AND t.name IN ('Stir-fry', 'Julienne', 'Marinate'))
  OR (r.name = 'Chicken Stock'                   AND t.name IN ('Make stock', 'Simmer'))
  OR (r.name = 'Hollandaise Sauce'               AND t.name IN ('Hollandaise', 'Reduction', 'Emulsify (vinaigrette)'))
  OR (r.name = 'Chicken Tagine'                  AND t.name IN ('Sauté', 'Marinate', 'Simmer', 'Butcher / break down chicken'))
ON CONFLICT DO NOTHING;
