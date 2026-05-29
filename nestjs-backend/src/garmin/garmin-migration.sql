-- Garmin Integration Tables
-- Run this manually on the MySQL production database

CREATE TABLE IF NOT EXISTS `garmin_connection` (
  `id` int NOT NULL AUTO_INCREMENT,
  `client_id` int NOT NULL,
  `access_token` text NOT NULL,
  `access_token_secret` text NOT NULL,
  `garmin_user_id` varchar(255) DEFAULT NULL,
  `garmin_display_name` varchar(255) DEFAULT NULL,
  `connected_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `last_sync_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `IDX_garmin_conn_client` (`client_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `garmin_activity` (
  `id` int NOT NULL AUTO_INCREMENT,
  `client_id` int NOT NULL,
  `garmin_activity_id` bigint NOT NULL,
  `garmin_user_token` varchar(255) DEFAULT NULL,
  `activity_type` varchar(100) DEFAULT NULL,
  `activity_name` varchar(255) DEFAULT NULL,
  `start_time` varchar(50) DEFAULT NULL,
  `duration_seconds` float DEFAULT NULL,
  `distance_meters` float DEFAULT NULL,
  `active_kcal` float DEFAULT NULL,
  `avg_heart_rate` float DEFAULT NULL,
  `max_heart_rate` float DEFAULT NULL,
  `avg_speed` float DEFAULT NULL,
  `steps` int DEFAULT NULL,
  `raw_json` longtext,
  `received_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `IDX_garmin_act_id` (`garmin_activity_id`),
  KEY `IDX_garmin_act_client` (`client_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `garmin_daily_summary` (
  `id` int NOT NULL AUTO_INCREMENT,
  `client_id` int NOT NULL,
  `calendar_date` varchar(10) NOT NULL,
  `steps` int DEFAULT NULL,
  `active_kcal` float DEFAULT NULL,
  `resting_heart_rate` float DEFAULT NULL,
  `max_heart_rate` float DEFAULT NULL,
  `avg_stress` float DEFAULT NULL,
  `body_battery_max` int DEFAULT NULL,
  `body_battery_min` int DEFAULT NULL,
  `sleep_duration_seconds` int DEFAULT NULL,
  `sleep_score` int DEFAULT NULL,
  `spo2_avg` float DEFAULT NULL,
  `respiration_avg` float DEFAULT NULL,
  `floors_climbed` int DEFAULT NULL,
  `intensity_minutes` int DEFAULT NULL,
  `raw_json` longtext,
  `received_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `IDX_garmin_daily_client_date` (`client_id`, `calendar_date`),
  KEY `IDX_garmin_daily_client` (`client_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
