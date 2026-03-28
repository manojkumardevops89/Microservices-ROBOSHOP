CREATE DATABASE IF NOT EXISTS cities;
USE cities;

CREATE TABLE IF NOT EXISTS cities (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    city      VARCHAR(100) NOT NULL,
    state     VARCHAR(100) NOT NULL,
    zip       VARCHAR(10)  NOT NULL
);

INSERT INTO cities (city, state, zip) VALUES
('Mumbai',    'Maharashtra', '400001'),
('Delhi',     'Delhi',       '110001'),
('Bangalore', 'Karnataka',   '560001'),
('Hyderabad', 'Telangana',   '500001'),
('Chennai',   'Tamil Nadu',  '600001');
