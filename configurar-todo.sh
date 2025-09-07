#!/bin/bash

echo "🚀 CONFIGURACIÓN AUTOMÁTICA COMPLETA DE VERCEL"
echo "==============================================="

cd estafeta-pro-dashboard

# Configurar variables de entorno en Vercel
echo "📝 Configurando variables de entorno..."

# Crear archivo .env.production para Vercel
cat > .env.production << EOF
NEXT_PUBLIC_SUPABASE_URL=https://kjswpfyzrzctelqburbm.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtqc3dwZnl6cnpjdGVscWJ1cmJtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYxOTMyMTIsImV4cCI6MjA3MTc2OTIxMn0.H8-1JOZWW7VnhMKzZvjshEsqYnDkvWMfRNeNlFSZhus
EOF

# Commit y redeploy
git add .env.production
git commit -m "Agregando variables de entorno de producción"

echo "🔄 Redespelogando a Vercel..."
npx vercel --prod --yes

echo "✅ CONFIGURACIÓN COMPLETA"
echo ""
echo "🎉 Tu aplicación está lista en:"
echo "👉 https://estafeta-dashboard.vercel.app"
echo ""
echo "🔑 Para entrar usa:"
echo "   Usuario: admin"
echo "   Contraseña: admin123"
