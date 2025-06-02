
# Laravel Multi-Project Dev Stack (Docker + Traefik + Nginx)

A lightweight, Docker-based development environment for managing multiple Laravel and Node.js (Nuxt, etc.) projects with local domain support via Traefik and Nginx.

---

## 📁 Folder Structure

```
dev-stack/
├── Dockerfile
├── docker-compose.yml
├── nginx/
│   └── conf.d/              # Nginx config files per project (git-ignored)
├── projects/                # Laravel/Nuxt project sources (git-ignored)
```

---

## ⚙️ Installation & Setup

### 1. Install Docker & Docker Compose
- Download and install Docker Desktop: [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)
- Ensure Docker works inside WSL2 if you're on Windows.

### 2. Create the Traefik network
Run this only once:

```bash
docker network create traefik
```

### 3. Start the Dev Stack
```bash
docker-compose up -d --build
```

### 4. Add local domains to your `hosts` file
On Windows, edit `C:\Windows\System32\drivers\etc\hosts` and add:

```
127.0.0.1 project_name.local phpmyadmin.local
```

### 5. Create a new Laravel project (example: parsitrip)
```bash
cd projects
laravel new project_name
```

### 6. Add Nginx config for the project
Create a file like `nginx/conf.d/parsitrip.local.conf` using a template (Laravel or Node.js)

### 7. Restart Nginx to apply changes
```bash
docker-compose restart nginx
```

---

## 💡 Useful Commands

- Enter PHP container:
```bash
docker exec -it php bash
```

- Run Laravel Artisan commands:
```bash
cd /var/www/project_name
php artisan migrate
```



Happy coding! 🚀
