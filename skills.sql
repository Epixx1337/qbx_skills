CREATE TABLE IF NOT EXISTS `skills_trees` (
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `category` VARCHAR(50) NOT NULL DEFAULT 'civilian',
    `description` TEXT DEFAULT NULL,
    `color` VARCHAR(20) DEFAULT NULL,
    `sort` INT NOT NULL DEFAULT 0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `jobs` LONGTEXT DEFAULT NULL,
    PRIMARY KEY (`name`)
);

CREATE TABLE IF NOT EXISTS `skills_nodes` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `tree` VARCHAR(50) NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `icon` VARCHAR(50) NOT NULL DEFAULT 'star',
    `x` INT NOT NULL DEFAULT 0,
    `y` INT NOT NULL DEFAULT 0,
    `cost` INT NOT NULL DEFAULT 1,
    `bonuses` LONGTEXT DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`),
    KEY `tree` (`tree`)
);

CREATE TABLE IF NOT EXISTS `skills_links` (
    `parent` INT NOT NULL,
    `child` INT NOT NULL,
    PRIMARY KEY (`parent`, `child`)
);

CREATE TABLE IF NOT EXISTS `skills_players` (
    `citizenid` VARCHAR(50) NOT NULL,
    `tree` VARCHAR(50) NOT NULL,
    `xp` INT NOT NULL DEFAULT 0,
    `level` INT NOT NULL DEFAULT 0,
    `points` INT NOT NULL DEFAULT 0,
    `unlocked` LONGTEXT DEFAULT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`, `tree`)
);

INSERT IGNORE INTO `skills_trees` (`name`, `label`, `category`, `description`, `sort`) VALUES
('shadow_work', 'Shadow Work', 'crime', 'A life spent around locked doors that were never yours. Picks, pins and patience.', 0),
('blue_collar', 'Blue Collar', 'civilian', 'Honest hands, honest pay. Work harder, work smarter and squeeze more out of every shift.', 1),
('second_wind', 'Second Wind', 'civilian', 'The body is a machine and you maintain yours well. Run further, hit the ground harder, get up anyway.', 2);

INSERT IGNORE INTO `skills_nodes` (`tree`, `name`, `label`, `description`, `icon`, `x`, `y`, `cost`, `bonuses`) VALUES
('shadow_work', 'nimble_fingers', 'Nimble Fingers', 'Your lockpicks last noticeably longer before snapping.', 'hand-sparkles', 2, 0, 1, '{"lockpick_durability":0.15}'),
('shadow_work', 'steady_hands', 'Steady Hands', 'The sweet spot on a lock is easier to hold. Lockpicking is faster.', 'hand', 1, 1, 1, '{"lockpick_speed":0.1}'),
('shadow_work', 'quick_entry', 'Quick Entry', 'You know which wire to cut first. Alarms trigger with a delay.', 'bolt', 3, 1, 1, '{"alarm_delay":2}'),
('shadow_work', 'master_locksmith', 'Master Locksmith', 'There is no lock in the city you have not seen the inside of.', 'unlock-keyhole', 1, 2, 2, '{"lockpick_speed":0.25}'),
('shadow_work', 'ghost', 'Ghost', 'In and out like you were never there. Lower chance of alerting the police.', 'ghost', 3, 2, 2, '{"police_alert_chance":-0.2}'),
('blue_collar', 'work_ethic', 'Work Ethic', 'First in, last out. All job payouts are slightly increased.', 'briefcase', 2, 0, 1, '{"payout_bonus":0.05}'),
('blue_collar', 'overtime', 'Overtime', 'The extra hours add up. Job payouts are increased further.', 'clock', 1, 1, 1, '{"payout_bonus":0.1}'),
('blue_collar', 'foreman', 'Foreman', 'You teach as you work. You gain skill experience faster.', 'helmet-safety', 3, 1, 1, '{"xp_bonus":0.1}'),
('second_wind', 'conditioning', 'Conditioning', 'A morning routine that actually sticks. Your stamina lasts longer.', 'person-running', 2, 0, 1, '{"stamina":10}'),
('second_wind', 'roadwork', 'Roadwork', 'Miles in the legs. Even more stamina.', 'stopwatch', 2, 1, 1, '{"stamina":15}'),
('second_wind', 'thick_skin', 'Thick Skin', 'You have taken a few hits in your life. A small boost to your maximum health.', 'heart', 1, 1, 1, '{"max_health":5}'),
('second_wind', 'unbreakable', 'Unbreakable', 'What does not kill you clearly made you harder to kill. More maximum health.', 'heart-pulse', 1, 2, 2, '{"max_health":10}'),
('second_wind', 'padded_up', 'Padded Up', 'You know how to wear a vest properly. A small boost to your maximum armour.', 'shield-halved', 3, 1, 1, '{"max_armour":5}'),
('second_wind', 'juggernaut', 'Juggernaut', 'Straps tight, plates seated. More maximum armour.', 'shield', 3, 2, 2, '{"max_armour":10}'),
('shadow_work', 'street_smarts', 'Street Smarts', 'You know who buys and for how much. Better prices when selling on the street.', 'user-secret', 2, 1, 1, '{"street_rep":0.1}'),
('shadow_work', 'green_thumb', 'Green Thumb', 'Your plants love you back. A chance at an extra bag when harvesting.', 'seedling', 2, 2, 1, '{"harvest_yield_chance":0.25}'),
('blue_collar', 'shop_hands', 'Shop Hands', 'You have turned enough wrenches to do it in your sleep. Repairs go faster.', 'screwdriver-wrench', 2, 1, 1, '{"repair_speed":0.15}');

INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'nimble_fingers' AND c.`name` = 'steady_hands';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'nimble_fingers' AND c.`name` = 'quick_entry';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'steady_hands' AND c.`name` = 'master_locksmith';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'quick_entry' AND c.`name` = 'ghost';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'work_ethic' AND c.`name` = 'overtime';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'work_ethic' AND c.`name` = 'foreman';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'conditioning' AND c.`name` = 'roadwork';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'conditioning' AND c.`name` = 'thick_skin';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'conditioning' AND c.`name` = 'padded_up';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'thick_skin' AND c.`name` = 'unbreakable';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'padded_up' AND c.`name` = 'juggernaut';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'nimble_fingers' AND c.`name` = 'street_smarts';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'street_smarts' AND c.`name` = 'green_thumb';
INSERT IGNORE INTO `skills_links` (`parent`, `child`) SELECT p.`id`, c.`id` FROM `skills_nodes` p, `skills_nodes` c WHERE p.`name` = 'work_ethic' AND c.`name` = 'shop_hands';
