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
