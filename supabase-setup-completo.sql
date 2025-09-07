-- Configuración completa de Supabase para Sistema Estafeta Colaborativo
-- Ejecutar en el SQL Editor de Supabase

-- 1. Crear tabla de usuarios
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) DEFAULT 'user',
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

-- 2. Crear tabla de progreso de usuarios
CREATE TABLE IF NOT EXISTS user_progress (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) REFERENCES users(username),
    processed_files INTEGER[],
    last_updated TIMESTAMP DEFAULT NOW(),
    total_files INTEGER DEFAULT 0,
    discrepancies_resolved INTEGER DEFAULT 0
);

-- 3. Crear tabla de archivos analizados
CREATE TABLE IF NOT EXISTS analyzed_files (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    file_type VARCHAR(50),
    upload_date TIMESTAMP DEFAULT NOW(),
    uploaded_by VARCHAR(50) REFERENCES users(username),
    total_records INTEGER DEFAULT 0,
    discrepancies_found INTEGER DEFAULT 0,
    financial_impact DECIMAL(12,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'processed'
);

-- 4. Crear tabla de discrepancias
CREATE TABLE IF NOT EXISTS discrepancies (
    id SERIAL PRIMARY KEY,
    file_id INTEGER REFERENCES analyzed_files(id),
    guide_number VARCHAR(50) NOT NULL,
    client_id VARCHAR(50),
    client_name VARCHAR(100),
    amount DECIMAL(10,2),
    discrepancy_type VARCHAR(50),
    observation TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP,
    resolved_by VARCHAR(50) REFERENCES users(username)
);

-- 5. Crear tabla de mensajes del equipo
CREATE TABLE IF NOT EXISTS team_messages (
    id SERIAL PRIMARY KEY,
    sender VARCHAR(50) REFERENCES users(username),
    message TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'info',
    created_at TIMESTAMP DEFAULT NOW(),
    is_read BOOLEAN DEFAULT false
);

-- 6. Crear tabla de sesiones activas
CREATE TABLE IF NOT EXISTS active_sessions (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) REFERENCES users(username),
    session_start TIMESTAMP DEFAULT NOW(),
    last_activity TIMESTAMP DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT
);

-- 7. Insertar usuarios por defecto
INSERT INTO users (username, full_name, role) VALUES
    ('admin', 'Administrador Principal', 'admin'),
    ('oscar', 'Oscar (Admin)', 'admin'),
    ('usuario', 'Usuario Estándar', 'user')
ON CONFLICT (username) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role;

-- 8. Insertar archivos de ejemplo (basados en el workspace real)
INSERT INTO analyzed_files (filename, file_type, uploaded_by, total_records, discrepancies_found, financial_impact, status) VALUES
    ('REPORTE DE GUIAS COBRADAS AL CLIENTE.xlsx', 'Guías Cobradas', 'admin', 1247, 46, 25000.00, 'processed'),
    ('REPORTE DE MI ESTAFETA.xlsx', 'Mi Estafeta', 'admin', 890, 0, 12000.00, 'processed'),
    ('REPORTE DE SHOPE ENVIOS.xlsx', 'Shopee Envíos', 'admin', 1201, 0, 18000.00, 'processed'),
    ('REPORTE SEMANAL.XLSX', 'Reporte Semanal', 'admin', 456, 0, 13500.00, 'processed')
ON CONFLICT DO NOTHING;

-- 9. Insertar discrepancias de ejemplo
INSERT INTO discrepancies (file_id, guide_number, client_id, client_name, amount, discrepancy_type, observation, status) VALUES
    (1, 'EST001234567', 'CLIENT001', 'Cliente Ejemplo 1', 1250.00, 'no_facturada', 'Guía cobrada sin aparecer en Shopee', 'pending'),
    (1, 'EST001234568', 'CLIENT002', 'Cliente Ejemplo 2', 980.50, 'diferencia_monto', 'Diferencia en monto cobrado vs registrado', 'pending'),
    (1, 'EST001234569', 'CLIENT003', 'Cliente Ejemplo 3', 1500.00, 'no_registrada', 'No aparece en el sistema de Shopee', 'pending'),
    (1, 'EST001234570', 'CLIENT004', 'Cliente Ejemplo 4', 750.00, 'duplicada', 'Posible duplicación de cobranza', 'pending'),
    (1, 'EST001234571', 'CLIENT005', 'Cliente Ejemplo 5', 2100.00, 'pendiente_revision', 'Requiere revisión manual', 'pending')
ON CONFLICT DO NOTHING;

-- 10. Crear políticas de seguridad (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE analyzed_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE discrepancies ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE active_sessions ENABLE ROW LEVEL SECURITY;

-- 11. Crear políticas para usuarios autenticados (acceso público para demo)
CREATE POLICY "Allow public read on users" ON users FOR SELECT USING (true);
CREATE POLICY "Allow public read on analyzed_files" ON analyzed_files FOR SELECT USING (true);
CREATE POLICY "Allow public read on discrepancies" ON discrepancies FOR SELECT USING (true);
CREATE POLICY "Allow public read on team_messages" ON team_messages FOR SELECT USING (true);
CREATE POLICY "Allow public insert on team_messages" ON team_messages FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public read on user_progress" ON user_progress FOR SELECT USING (true);
CREATE POLICY "Allow public insert/update on user_progress" ON user_progress FOR ALL USING (true);

-- 12. Crear funciones útiles
CREATE OR REPLACE FUNCTION get_team_stats()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_users', (SELECT COUNT(*) FROM users WHERE is_active = true),
        'active_sessions', (SELECT COUNT(*) FROM active_sessions WHERE last_activity > NOW() - INTERVAL '30 minutes'),
        'total_files', (SELECT COUNT(*) FROM analyzed_files),
        'total_discrepancies', (SELECT COUNT(*) FROM discrepancies WHERE status = 'pending'),
        'financial_impact', (SELECT COALESCE(SUM(financial_impact), 0) FROM analyzed_files)
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 13. Crear función para actualizar actividad de usuario
CREATE OR REPLACE FUNCTION update_user_activity(p_username VARCHAR(50))
RETURNS VOID AS $$
BEGIN
    UPDATE users SET last_login = NOW() WHERE username = p_username;
    
    INSERT INTO active_sessions (user_id, last_activity)
    VALUES (p_username, NOW())
    ON CONFLICT (user_id) DO UPDATE SET last_activity = NOW();
END;
$$ LANGUAGE plpgsql;

-- 14. Crear vista para dashboard principal
CREATE OR REPLACE VIEW dashboard_summary AS
SELECT 
    (SELECT COUNT(*) FROM analyzed_files) as total_files,
    (SELECT COUNT(*) FROM discrepancies WHERE status = 'pending') as pending_discrepancies,
    (SELECT COUNT(*) FROM users WHERE is_active = true) as active_users,
    (SELECT COALESCE(SUM(financial_impact), 0) FROM analyzed_files) as total_financial_impact,
    (SELECT COUNT(*) FROM active_sessions WHERE last_activity > NOW() - INTERVAL '30 minutes') as online_users;

-- 15. Insertar mensaje de bienvenida
INSERT INTO team_messages (sender, message, message_type) VALUES
    ('admin', '🎉 Sistema de Análisis de Guías Estafeta iniciado. 46 discrepancias detectadas para revisión.', 'info'),
    ('admin', '📊 Dashboard colaborativo configurado con Supabase. ¡El equipo puede trabajar en tiempo real!', 'success')
ON CONFLICT DO NOTHING;

-- Confirmación
SELECT 
    'Configuración completa de Supabase terminada' as status,
    get_team_stats() as estadisticas;
