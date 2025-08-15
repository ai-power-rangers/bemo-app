-- SpellQuest Content Seed Data
-- Run this AFTER the migration to populate with sample content

-- Insert starter albums
INSERT INTO spellquest_albums (
    album_id, title, difficulty, is_official, order_index, published_at, tags
) VALUES 
    ('starter_pack', 'Starter Pack', 1, true, 0, NOW(), ARRAY['beginner', 'free']),
    ('animals', 'Animals', 1, true, 1, NOW(), ARRAY['nature', 'beginner']),
    ('fruits', 'Fruits & Vegetables', 1, true, 2, NOW(), ARRAY['food', 'healthy']),
    ('vehicles', 'Vehicles', 2, true, 3, NOW(), ARRAY['transport', 'city'])
ON CONFLICT (album_id) DO NOTHING;

-- Insert puzzles for starter_pack album
INSERT INTO spellquest_puzzles (
    puzzle_id, album_id, word, display_title, image_path, difficulty, order_index, is_official, published_at
) VALUES 
    -- Starter Pack (3-letter words)
    ('cat_starter', (SELECT id FROM spellquest_albums WHERE album_id = 'starter_pack'), 'CAT', 'Cat', 'starter_pack/cat.png', 1, 1, true, NOW()),
    ('dog_starter', (SELECT id FROM spellquest_albums WHERE album_id = 'starter_pack'), 'DOG', 'Dog', 'starter_pack/dog.png', 1, 2, true, NOW()),
    ('bus_starter', (SELECT id FROM spellquest_albums WHERE album_id = 'starter_pack'), 'BUS', 'Bus', 'starter_pack/bus.png', 1, 3, true, NOW()),
    ('sun_starter', (SELECT id FROM spellquest_albums WHERE album_id = 'starter_pack'), 'SUN', 'Sun', 'starter_pack/sun.png', 1, 4, true, NOW()),
    
    -- Animals (3-5 letter words)
    ('cat', (SELECT id FROM spellquest_albums WHERE album_id = 'animals'), 'CAT', 'Cat', 'animals/cat.png', 1, 1, true, NOW()),
    ('dog', (SELECT id FROM spellquest_albums WHERE album_id = 'animals'), 'DOG', 'Dog', 'animals/dog.png', 1, 2, true, NOW()),
    ('bird', (SELECT id FROM spellquest_albums WHERE album_id = 'animals'), 'BIRD', 'Bird', 'animals/bird.png', 1, 3, true, NOW()),
    ('fish', (SELECT id FROM spellquest_albums WHERE album_id = 'animals'), 'FISH', 'Fish', 'animals/fish.png', 1, 4, true, NOW()),
    ('mouse', (SELECT id FROM spellquest_albums WHERE album_id = 'animals'), 'MOUSE', 'Mouse', 'animals/mouse.png', 2, 5, true, NOW()),
    ('horse', (SELECT id FROM spellquest_albums WHERE album_id = 'animals'), 'HORSE', 'Horse', 'animals/horse.png', 2, 6, true, NOW()),
    
    -- Fruits (4-6 letter words)
    ('apple', (SELECT id FROM spellquest_albums WHERE album_id = 'fruits'), 'APPLE', 'Apple', 'fruits/apple.png', 1, 1, true, NOW()),
    ('pear', (SELECT id FROM spellquest_albums WHERE album_id = 'fruits'), 'PEAR', 'Pear', 'fruits/pear.png', 1, 2, true, NOW()),
    ('banana', (SELECT id FROM spellquest_albums WHERE album_id = 'fruits'), 'BANANA', 'Banana', 'fruits/banana.png', 2, 3, true, NOW()),
    ('orange', (SELECT id FROM spellquest_albums WHERE album_id = 'fruits'), 'ORANGE', 'Orange', 'fruits/orange.png', 2, 4, true, NOW()),
    ('grape', (SELECT id FROM spellquest_albums WHERE album_id = 'fruits'), 'GRAPE', 'Grape', 'fruits/grape.png', 1, 5, true, NOW()),
    ('carrot', (SELECT id FROM spellquest_albums WHERE album_id = 'fruits'), 'CARROT', 'Carrot', 'fruits/carrot.png', 2, 6, true, NOW()),
    
    -- Vehicles (3-8 letter words)
    ('car', (SELECT id FROM spellquest_albums WHERE album_id = 'vehicles'), 'CAR', 'Car', 'vehicles/car.png', 1, 1, true, NOW()),
    ('bus', (SELECT id FROM spellquest_albums WHERE album_id = 'vehicles'), 'BUS', 'Bus', 'vehicles/bus.png', 1, 2, true, NOW()),
    ('bike', (SELECT id FROM spellquest_albums WHERE album_id = 'vehicles'), 'BIKE', 'Bike', 'vehicles/bike.png', 1, 3, true, NOW()),
    ('train', (SELECT id FROM spellquest_albums WHERE album_id = 'vehicles'), 'TRAIN', 'Train', 'vehicles/train.png', 2, 4, true, NOW()),
    ('plane', (SELECT id FROM spellquest_albums WHERE album_id = 'vehicles'), 'PLANE', 'Plane', 'vehicles/plane.png', 2, 5, true, NOW()),
    ('airplane', (SELECT id FROM spellquest_albums WHERE album_id = 'vehicles'), 'AIRPLANE', 'Airplane', 'vehicles/airplane.png', 3, 6, true, NOW())
ON CONFLICT (puzzle_id) DO NOTHING;

-- Verify the data was inserted
SELECT 
    a.album_id,
    a.title as album_title,
    COUNT(p.id) as puzzle_count
FROM spellquest_albums a
LEFT JOIN spellquest_puzzles p ON a.id = p.album_id
GROUP BY a.album_id, a.title
ORDER BY a.order_index;