CREATE TABLE branch_history(
  id INTEGER PRIMARY KEY AUTOINCREMENT
  ,
  path VARCHAR(1024) NOT NULL
  ,
  branch VARCHAR(256) NOT NULL
  ,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE pr_history(
  id INTEGER NOT NULL PRIMARY KEY,
  repo VARCHAR(255),
  branch VARCHAR(255),
  pr VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP
);
CREATE TABLE `slorks`(
  `id` integer NOT NULL PRIMARY KEY AUTOINCREMENT,
  `repo` varchar(255) NOT NULL,
  `board` varchar(255) NOT NULL,
  `ticket` integer NOT NULL,
  `pr` integer,
  `title` varchar(255) NOT NULL,
  `status` varchar(255) NOT NULL,
  `notes` varchar(255),
  `created_at` timestamp,
  `updated_at` timestamp,
  `deleted_at` timestamp,
  project_code varchar(255)
);
CREATE TABLE parent_branches(
  id INTEGER NOT NULL PRIMARY KEY,
  repo TEXT NOT NULL,
  branch TEXT NOT NULL,
  parent TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP DEFAULT NULL
);
CREATE TABLE durations(
  id INTEGER PRIMARY KEY,
  slork_id INTEGER NOT NULL,
  label VARCHAR(255),
  notes TEXT,
  ms INTEGER NOT NULL CHECK(ms >= 0),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  hms TEXT GENERATED ALWAYS AS(printf('%d:%02d:%02d.%03d',
CAST(ms/3600000 AS INTEGER),
CAST(ms/60000 AS INTEGER) % 60,
CAST(ms/1000 AS INTEGER) % 60,
ms % 1000)) VIRTUAL,
  FOREIGN KEY(slork_id) REFERENCES slorks(id)
);
