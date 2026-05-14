# ── STAGE 1: instalación de dependencias ──────────────────────────────────────
# Usamos node:18-alpine como base. Alpine pesa ~5MB vs ~900MB de la imagen
# completa, lo que reduce la superficie de ataque (seguridad) y el tiempo
# de descarga en EC2.
FROM node:18-alpine AS builder

WORKDIR /app

# Copiamos SOLO los manifiestos de dependencias primero.
# Docker cachea por capas: si package.json no cambia, esta capa
# no se reconstruye, acelerando builds posteriores.
COPY package*.json ./

# npm ci es más estricto que npm install: usa package-lock.json exacto,
# más reproducible y seguro para CI/CD.
RUN npm ci --only=production

# ── STAGE 2: imagen final de ejecución ────────────────────────────────────────
# Partimos de la misma base limpia. El resultado final NO incluye
# herramientas de build ni cachés del stage anterior.
FROM node:18-alpine AS runner

# Principio de mínimo privilegio: creamos un usuario sin permisos de root.
# Si el contenedor fuera comprometido, el atacante no tendría acceso root
# al sistema host ni a otros contenedores.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copiamos desde el stage builder SOLO node_modules ya instalados.
# No copiamos npm, caché, ni archivos temporales de la instalación.
COPY --from=builder /app/node_modules ./node_modules

# Copiamos el código fuente de la aplicación.
COPY . .

# Asignamos ownership al usuario no-root antes de cambiar de usuario.
RUN chown -R appuser:appgroup /app

# Cambiamos al usuario no-root. A partir de aquí ningún proceso
# dentro del contenedor corre como root.
USER appuser

EXPOSE 3001

CMD ["node", "server.js"]