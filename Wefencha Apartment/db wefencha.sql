start transaction;
create database wefencha;
use wefencha;
start transaction;
CREATE TABLE apartment (
    apartment_id INT PRIMARY KEY,
    address varchar(50) not null,
    building_name VARCHAR(20),
    floor_number INT,
    room_number INT,
    room_type VARCHAR(30),
    rent_price DECIMAL(10,2 ) not null
);

INSERT INTO apartment (apartment_id,address, building_name,Floor_number, Room_number, Room_type, Rent_Price) VALUES
('001','gubre','wefencha','01','0001','studio','10000'),
('002','gubre','wefencha','02','0002','1_bed_room','15000'),
('003','gubre','wefencha','03','0003','3_bed_room','20000');
INSERT INTO apartment (apartment_id,address, building_name,Floor_number, Room_number, Room_type, Rent_Price) VALUES
('004','gubre','wefencha','02','0005','studio','10000');
select* from apartment;
CREATE TABLE tenant (
    tenant_id INT PRIMARY KEY,
    first_name VARCHAR(50) not null, 
    last_name VARCHAR(50),
    phone VARCHAR(20),
    email VARCHAR(100),
    address VARCHAR(150),
    emergency_address varchar(30)
);
INSERT INTO Tenant ( tenant_id,first_name, last_name ,phone ,email ,address ,emergency_address ) values
('1001', 'dagmawit','mekonnen','+251902928374 ','dagi12@gmail.com', 'Piassa, Addis Ababa', ' Sister: +251922345678'),
('2002', 'elham','abdu','+251902928374 ','elu12@gmail.com', 'mercato, Addis Ababa', ' father: +251922347654'),
('3003', 'meaza','telahun','+251954738298 ','meazi12@gmail.com', 'agena, wolkite', ' husband: +251945638239'),
('4004', 'abebech','chala','+251954187577 ','abebech12@gmail.com', 'yergalem, hawassa', ' mother: +251999887755');
select*from tenant;
CREATE TABLE lease (
    lease_id INT PRIMARY KEY,
    apartment_id INT not null,
    tenant_id INT not null,
    start_date DATE,
    end_date DATE,
    monthly_rent DECIMAL(10,2),
    
    FOREIGN KEY (apartment_id) REFERENCES apartment(apartment_id) ON DELETE CASCADE, 
    FOREIGN KEY (tenant_id) REFERENCES tenant(tenant_id) ON DELETE CASCADE,
    constraint chk_dates check(end_date > start_date)
);
insert into lease(lease_id,apartment_id ,tenant_id ,start_date ,end_date ,monthly_rent) values
('110','001','1001','2025-09-05','2026-02-05','10000'),
('111','002','2002','2025-07-09','2026-01-09','15000'),
('112','003','3003','2025-09-12','2026-04-12','20000'),
('113','004','4004','2025-07-31','2026-01-31','10000');
select *from lease;
CREATE TABLE payment (
    payment_id INT PRIMARY KEY,
    lease_id INT,
    payment_date DATE,
    amount DECIMAL(10,2),
    payment_method VARCHAR(30),
    status VARCHAR(20),
    FOREIGN KEY (lease_id) REFERENCES lease(lease_id) ON DELETE cascade
);
insert into payment( payment_id,lease_id ,payment_date ,amount ,payment_method,status) values
('1010','110','2025-09-05','10000','cash','paid'),
('1011','111','2025-07-09','15000','check','unpaid'),
('1012','112','2025-09-12','20000','cash','paid'),
('1013','113','2025-07-31','10000','check','unpaid');
select*from payment;
-- Query: Get Apartment details and the Tenant assigned to them
SELECT 
    a.apartment_id, 
    a.building_name, 
    a.room_number, 
    t.first_name, 
    t.last_name, 
    l.start_date
FROM apartment a
INNER JOIN lease l ON a.apartment_id = l.apartment_id
INNER JOIN tenant t ON l.tenant_id = t.tenant_id;
-- Query: List all apartments and show if they are leased or vacant
SELECT 
    a.apartment_id, 
    a.room_number, 
    l.lease_id,
    CASE 
        WHEN l.lease_id IS NULL THEN 'VACANT' 
        ELSE 'OCCUPIED' 
    END AS occupancy_status
FROM apartment a
LEFT JOIN lease l ON a.apartment_id = l.apartment_id;
-- Query: See all payments and their corresponding lease dates
SELECT 
    p.payment_id, 
    p.amount, 
    p.status, 
    l.start_date, 
    l.end_date
FROM lease l
RIGHT JOIN payment p ON l.lease_id = p.lease_id;
DELIMITER //
CREATE PROCEDURE GetApartmentOccupancyStatus()
BEGIN
    SELECT
        a.apartment_id,
        a.room_number,
        a.room_type,
        a.rent_price,
        l.lease_id,
        CASE
            WHEN l.lease_id IS NULL THEN 'VACANT'
            ELSE 'OCCUPIED'
        END AS occupancy_status
    FROM apartment a
    LEFT JOIN lease l ON a.apartment_id = l.apartment_id
    ORDER BY a.apartment_id;
END //
DELIMITER ;
CALL GetApartmentOccupancyStatus();
DELIMITER //
CREATE PROCEDURE GetTenantDetailsById (
    IN p_tenant_id INT
)
BEGIN
    SELECT
        t.tenant_id,
        t.first_name,
        t.last_name,
        t.phone,
        t.email,
        t.address AS tenant_address,
        a.apartment_id,
        a.building_name,
        a.room_number,
        a.room_type,
        l.start_date,
        l.end_date,
        l.monthly_rent
    FROM tenant t
    LEFT JOIN lease l ON t.tenant_id = l.tenant_id
    LEFT JOIN apartment a ON l.apartment_id = a.apartment_id
    WHERE t.tenant_id = p_tenant_id;
END //
DELIMITER ;
CALL GetTenantDetailsById(1001);
CREATE TABLE Rent_Change_Log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    apartment_id INT,
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
DELIMITER //
CREATE TRIGGER after_apartment_price_update
AFTER UPDATE ON apartment
FOR EACH ROW
BEGIN
    IF OLD.rent_price <> NEW.rent_price THEN
        INSERT INTO Rent_Change_Log (apartment_id, old_price, new_price)
        VALUES (OLD.apartment_id, OLD.rent_price, NEW.rent_price);
    END IF;
END //
DELIMITER ;
DELIMITER //
CREATE TRIGGER prevent_double_booking
BEFORE INSERT ON lease
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM lease
        WHERE apartment_id = NEW.apartment_id
        AND NEW.start_date < end_date
        AND NEW.end_date > start_date
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: This apartment is already leased during the selected dates!';
    END IF;
END //
DELIMITER 
DELIMITER //
CREATE TRIGGER validate_monthly_rent
BEFORE INSERT ON lease
FOR EACH ROW
BEGIN
    DECLARE apt_rent DECIMAL(10,2);
    SELECT rent_price INTO apt_rent
    FROM apartment
    WHERE apartment_id = NEW.apartment_id;
    
    IF NEW.monthly_rent != apt_rent THEN
        SET NEW.monthly_rent = apt_rent;  -- Auto-correct
    END IF;
END //
DELIMITER ;
grant select,insert,update
 on tenant
 to 'tenant';
REVOKE INSERT, UPDATE, DELETE ON 
payment FROM 'tenant';
commit;
