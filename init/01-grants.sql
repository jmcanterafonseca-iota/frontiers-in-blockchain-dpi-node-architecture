CREATE USER 'node_consumer'@'%' IDENTIFIED BY 'node';
CREATE USER 'node_provider'@'%' IDENTIFIED BY 'node';

GRANT ALL PRIVILEGES ON dpi_consumer.* TO 'node_consumer'@'%'; 
FLUSH PRIVILEGES;

GRANT ALL PRIVILEGES ON dpi_provider.* TO 'node_provider'@'%'; 
FLUSH PRIVILEGES;
