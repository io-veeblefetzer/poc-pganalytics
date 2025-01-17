\c pocpg

-- Create the table with miners
CREATE TABLE
    IF NOT EXISTS miners (
        id smallint,
        name varchar(20),
        graphic_cards smallint
    );

-- Insert the miners as a fixed list
INSERT INTO
    miners (id, name, graphic_cards)
VALUES
    (1, 'Diamond', 10),
    (2, 'Platinum', 7),
    (3, 'Gold', 4),
    (4, 'Silver', 2),
    (5, 'Rust', 1);

-- Then create a cross join to generate the metrics data
CREATE TABLE
    IF NOT EXISTS metrics AS (
        SELECT
            miners.name,
            s1.time as time,
            random () * (100 - 0) + 0 AS cpu_usage,
            random () * (30 - 26) + 26 * graphic_cards AS average_mhs,
            random () * (90 - 50) + 50 AS temperature,
            random () * (100 - 0) + 0 AS fan
        FROM
            generate_series ('2023-1-1', '2025-1-1', INTERVAL '1 hour') AS s1 (time)
            CROSS JOIN (
                SELECT
                    id,
                    name,
                    graphic_cards
                FROM
                    miners
            ) miners
        ORDER BY
            miners.id,
            s1.time
    );