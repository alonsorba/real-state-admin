# Etapa 1: dependencias PHP (Composer)
FROM composer:2 AS composer_stage
WORKDIR /app

# Copiamos solo lo mínimo para aprovechar caché
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-interaction --prefer-dist

# Ahora copiamos todo el código y terminamos la instalación
COPY . .
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Etapa 2: assets front (npm / Laravel Mix)
FROM node:16 AS assets_stage
WORKDIR /app

COPY package.json package-lock.json webpack.mix.js ./
RUN npm install

COPY resources ./resources
COPY public ./public
RUN npm run prod

# Etapa 3: imagen final de producción
FROM php:7.4-apache

# Instalar extensiones necesarias para Laravel
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    && docker-php-ext-install pdo_mysql mbstring zip \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# Directorio de la app
WORKDIR /var/www/html

# Copiamos la app ya preparada (PHP)
COPY --from=composer_stage /app ./

# Copiamos los assets compilados
COPY --from=assets_stage /app/public ./public

# Configuramos Apache para servir desde /public
RUN sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/public|g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|<Directory /var/www/>|<Directory /var/www/html/public/>|g' /etc/apache2/apache2.conf

# Permisos para storage y cache
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 storage bootstrap/cache

# Puerto del contenedor
EXPOSE 80

# Comando por defecto
CMD ["apache2-foreground"]
