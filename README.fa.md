# Dockavel

[![CI](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml/badge.svg)](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml)

[English](README.md) | **فارسی**

Dockavel یک محیط توسعه محلی قابل تنظیم برای اجرای هم‌زمان چند پروژه **Laravel و Node.js** است که بر پایه Docker Compose و Nginx ساخته شده است.

هدف Dockavel این است که اگر چند پروژه با نسخه‌های متفاوت PHP، دیتابیس‌های مختلف، Redis، Node.js یا دامنه‌های محلی متفاوت دارید، مجبور نباشید برای هر پروژه یک استک جدا و تکراری بسازید. می‌توانید فقط سرویس‌هایی را که لازم دارید فعال کنید، چند نسخه PHP را هم‌زمان اجرا کنید و برای شرایط شبکه‌ای مختلف از mirrorهای منطقه‌ای استفاده کنید.

## چرا Dockavel؟

وقتی فقط یک پروژه دارید، یک فایل ساده Docker Compose معمولاً کافی است. اما با افزایش تعداد پروژه‌ها مشکلاتی مثل این‌ها ایجاد می‌شود:

- یک پروژه PHP 8.2 می‌خواهد و پروژه دیگر PHP 8.5
- بعضی پروژه‌ها MySQL و بعضی PostgreSQL می‌خواهند
- چند پروژه به Redis یا Node.js مشترک نیاز دارند
- برای هر پروژه یک دامنه محلی جدا لازم است
- دسترسی مستقیم به registryها و repositoryهای جهانی همیشه پایدار نیست

Dockavel این زیرساخت را در یک محیط مشترک مدیریت می‌کند.

## امکانات

- اجرای هم‌زمان PHP-FPM نسخه‌های **8.2، 8.3، 8.4 و 8.5**
- MySQL 8 به‌صورت اختیاری
- PostgreSQL 17 به‌صورت اختیاری
- Redis 7 به‌صورت اختیاری
- Node.js 24 به‌صورت اختیاری
- phpMyAdmin و pgAdmin به‌صورت اختیاری
- استفاده از Docker Compose Profiles برای فعال کردن فقط سرویس‌های موردنیاز
- نصب‌کننده تعاملی `setup.sh`
- انتخاب منبع دانلود برای Docker imageها و package repositoryها
- presetهای Official، IranServer، Runflare، China و Custom
- مسیریابی پروژه‌ها با Nginx به runtime مناسب
- پوشه مشترک `projects/` برای همه runtimeها
- پشتیبانی PHP از MySQL، PostgreSQL، Redis، Composer و نیازهای رایج Laravel
- هماهنگی UID/GID برای کاهش مشکل فایل‌های root-owned
- امکان اضافه کردن سرویس‌های جدید با اجرای دوباره setup
- تست خودکار Compose و runtimeها در GitHub Actions
- عدم وابستگی به image خصوصی یا image اختصاصی Dockavel در registryها

## معماری

```text
Browser
   │
   ▼
 Nginx :80
   │
   ├── legacy.local   ──► php82:9000
   ├── api.local      ──► php84:9000
   ├── modern.local   ──► php85:9000
   └── frontend.local ──► node:3000

Shared services
   │
   ├── MySQL 8       (اختیاری)
   ├── PostgreSQL 17 (اختیاری)
   ├── Redis 7       (اختیاری)
   └── Node.js 24    (اختیاری)

Database tools
   │
   ├── phpMyAdmin    (اختیاری)
   └── pgAdmin       (اختیاری)
```

تمام پروژه‌ها از طریق volume مشترک زیر در دسترس runtimeها هستند:

```text
./projects → /var/www
```

بنابراین چند پروژه مختلف می‌توانند هم‌زمان روی نسخه‌های متفاوت PHP اجرا شوند.

## سرویس‌ها و Profileها

| سرویس | نسخه / نوع | Compose profile |
| --- | --- | --- |
| PHP-FPM | 8.2 | `php82` |
| PHP-FPM | 8.3 | `php83` |
| PHP-FPM | 8.4 | `php84` |
| PHP-FPM | 8.5 | `php85` |
| MySQL | 8.0 | `mysql` |
| PostgreSQL | 17 Alpine | `postgres` |
| Redis | 7 Alpine | `redis` |
| Node.js | 24 Bookworm Slim | `node` |
| phpMyAdmin | image رسمی upstream | `mysql-ui` |
| pgAdmin | 9 | `postgres-ui` |
| Nginx | Alpine | همیشه فعال |

PHPها به‌صورت محلی از image عمومی زیر build می‌شوند:

```text
serversideup/php:<version>-fpm
```

Node.js نیز از image عمومی زیر build می‌شود:

```text
node:24-bookworm-slim
```

آدرس واقعی این imageها بر اساس mirror انتخاب‌شده تغییر می‌کند.

برای اجرای Dockavel نیازی به Docker Hub account، GHCR account یا registry خصوصی Dockavel ندارید.

## پیش‌نیازها

- Docker Engine یا Docker Desktop
- Docker Compose v2
- Bash
- ترمینال interactive
- آزاد بودن پورت `80` برای Nginx

در Windows استفاده از **WSL2** پیشنهاد می‌شود.

برای بررسی Docker:

```bash
docker --version
docker compose version
```

## نصب سریع

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
chmod +x setup.sh
./setup.sh
```

در اولین اجرا، اگر `.env` وجود نداشته باشد، از روی `.env.example` ساخته می‌شود.

setup به‌ترتیب از شما می‌خواهد موارد زیر را انتخاب کنید:

1. منبع دانلود
2. نسخه‌های PHP
3. دیتابیس‌ها
4. سرویس‌های اختیاری
5. ابزارهای مدیریت دیتابیس
6. build و start شدن استک

کلیدهای کنترل:

- `↑` و `↓` برای جابه‌جایی
- `Space` برای انتخاب یا برداشتن انتخاب
- `Enter` برای تأیید

مثال:

```text
Download source
[x] Iran / IranServer

PHP runtimes
[x] PHP 8.2
[ ] PHP 8.3
[ ] PHP 8.4
[x] PHP 8.5

Databases
[x] MySQL 8
[x] PostgreSQL 17

Optional services
[x] Redis 7
[x] Node.js 24

Database tools
[x] phpMyAdmin
[ ] pgAdmin
```

در این حالت مقدار زیر در `.env` ساخته می‌شود:

```env
COMPOSE_PROFILES=php82,php85,mysql,postgres,redis,node,mysql-ui
```

قبل از اجرای استک، setup ابتدا Compose configuration را validate می‌کند.

اگر گزینه Build and start را انتخاب کنید، رفتار معادل این دستورات است:

```bash
docker compose pull --ignore-buildable
docker compose up -d --build
```

گزینه `--ignore-buildable` باعث می‌شود سرویس‌های PHP و Node که قرار است روی سیستم محلی build شوند، به اشتباه به‌عنوان image آماده از registry درخواست نشوند.

## منبع‌های دانلود

Dockavel منبع Docker image و package repositoryها را در قالب یک preset مدیریت می‌کند.

وقتی یک preset منطقه‌ای انتخاب می‌شود، Dockavel به‌صورت عمدی برای سرویس‌هایش fallback مخفی به registry دیگری انجام نمی‌دهد.

### Official / Global

```text
Docker images : docker.io
Debian        : deb.debian.org
Composer      : repo.packagist.org
npm           : registry.npmjs.org
```

### Iran / IranServer

```text
Docker library   : docker.iranserver.com/library/
Docker namespace : docker.iranserver.com/
Debian            : mirror.iranserver.com
Composer          : composer.iranserver.com
npm               : npm.iranserver.com
```

برای مثال PHP 8.2 از این مسیر دریافت می‌شود:

```text
docker.iranserver.com/serversideup/php:8.2-fpm
```

و Node.js:

```text
docker.iranserver.com/library/node:24-bookworm-slim
```

### Iran / Runflare

در این حالت Docker، Debian، Composer و npm از mirrorهای Runflare استفاده می‌شوند.

محدودیت درخواست، quota و availability این سرویس توسط Runflare تعیین می‌شود و ممکن است در طول زمان تغییر کند.

### China / regional mirrors

- Docker: DaoCloud
- Debian: Tsinghua
- Composer: Aliyun
- npm: npmmirror

### Custom endpoints

در حالت Custom می‌توانید این مقادیر را خودتان تعیین کنید:

- Docker library prefix
- Docker namespace prefix
- Debian mirror
- Debian security mirror
- Composer repository
- npm registry
- npm strict SSL

این تنظیمات در `.env` ذخیره می‌شوند و نیازی به تغییر فایل‌های commit‌شده نیست.

## نحوه کار PHP Runtimeها

برای همه نسخه‌های PHP فقط یک `Dockerfile` وجود دارد.

نسخه PHP از طریق `PHP_VERSION` تعیین می‌شود.

نمونه upstreamها:

```text
serversideup/php:8.2-fpm
serversideup/php:8.3-fpm
serversideup/php:8.4-fpm
serversideup/php:8.5-fpm
```

prefix مربوط به Docker namespace بر اساس source preset به Dockerfile ارسال می‌شود.

نام سرویس‌های PHP:

```text
php82
php83
php84
php85
```

سرویس `php82` برای backward compatibility یک network alias به نام `php` نیز دارد.

## اضافه کردن سرویس به استک موجود

برای اضافه کردن سرویس جدید لازم نیست کل Dockavel را حذف و از ابتدا نصب کنید.

دوباره اجرا کنید:

```bash
./setup.sh
```

انتخاب‌های قبلی را نگه دارید و سرویس جدید را هم تیک بزنید.

مثلاً اگر ابتدا این تنظیمات را داشته باشید:

```env
COMPOSE_PROFILES=php82,php85,mysql,redis,node,mysql-ui
```

بعداً می‌توانید PostgreSQL را اضافه کنید:

```env
COMPOSE_PROFILES=php82,php85,mysql,postgres,redis,node,mysql-ui
```

Docker Compose تا جای ممکن imageها، build cache، volumeها و containerهای بدون تغییر را reuse می‌کند و سرویس جدید را اضافه می‌کند.

اجرای مجدد setup باعث حذف volumeهای دیتابیس نمی‌شود.

## ساختار پروژه

```text
Dockavel/
├── projects/
│   ├── legacy-crm/
│   ├── booking-api/
│   └── frontend/
├── nginx/
│   ├── conf.d/
│   ├── template-laravel.conf.example
│   └── template-node.conf.example
├── Dockerfile
├── Dockerfile-node
├── docker-compose.yml
├── setup.sh
└── .env
```

## اضافه کردن پروژه Laravel

پروژه را داخل این مسیر قرار دهید:

```text
projects/my-api
```

سپس برای آن Nginx config بسازید:

```text
nginx/conf.d/my-api.local.conf
```

مثال برای PHP 8.5:

```nginx
server {
    listen 80;
    server_name my-api.local;

    root /var/www/my-api/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass php85:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $document_root;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

دامنه را به hosts سیستم اضافه کنید:

```text
127.0.0.1 my-api.local
```

و Nginx را restart کنید:

```bash
docker compose restart nginx
```

همچنین می‌توانید از فایل آماده زیر شروع کنید:

```text
nginx/template-laravel.conf.example
```

## اجرای چند نسخه PHP به‌صورت هم‌زمان

مثال:

```text
projects/
├── old-app/       # PHP 8.2
├── internal-api/  # PHP 8.4
└── new-app/       # PHP 8.5
```

برای هر دامنه می‌توان runtime متفاوت تعیین کرد:

```nginx
fastcgi_pass php82:9000;
```

```nginx
fastcgi_pass php84:9000;
```

```nginx
fastcgi_pass php85:9000;
```

## دستورات PHP و Composer

بررسی نسخه PHP:

```bash
docker compose exec php82 php -v
docker compose exec php85 php -v
```

ورود به container:

```bash
docker compose exec php85 bash
```

اجرای پروژه:

```bash
docker compose exec php85 bash
cd /var/www/my-api
composer install
php artisan migrate
```

Composer از repository انتخاب‌شده در source preset استفاده می‌کند.

## پروژه‌های Node.js

Node نیز پوشه `projects/` را در `/var/www` mount می‌کند.

بررسی نسخه:

```bash
docker compose exec node node --version
docker compose exec node npm --version
```

نصب dependencyها:

```bash
docker compose exec node bash
cd /var/www/frontend
npm install
```

پروژه‌های Node می‌توانند روی پورت‌های داخلی محدوده زیر اجرا شوند:

```text
3000-3099
```

برای Nginx reverse proxy می‌توانید از این template استفاده کنید:

```text
nginx/template-node.conf.example
```

## MySQL

آدرس داخل Docker network:

```text
mysql:3306
```

آدرس روی host:

```text
127.0.0.1:13307
```

مثال Laravel:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret
```

داده‌ها در volume زیر نگهداری می‌شوند:

```text
mysql_data
```

## PostgreSQL

آدرس داخل Docker network:

```text
postgres:5432
```

آدرس روی host:

```text
127.0.0.1:15432
```

مثال Laravel:

```env
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=secret
```

داده‌ها در volume زیر نگهداری می‌شوند:

```text
postgres_data
```

## Redis

داخل Docker:

```text
redis:6379
```

روی host:

```text
127.0.0.1:16379
```

مثال Laravel:

```env
REDIS_HOST=redis
REDIS_PORT=6379
```

## ابزارهای مدیریت دیتابیس

### phpMyAdmin

اگر `mysql-ui` فعال باشد:

```text
http://127.0.0.1:18080
```

برای Server از `mysql` استفاده کنید.

### pgAdmin

اگر `postgres-ui` فعال باشد:

```text
http://127.0.0.1:18081
```

برای اتصال PostgreSQL:

```text
Host: postgres
Port: 5432
```

داده‌های pgAdmin در volume زیر نگهداری می‌شوند:

```text
pgadmin_data
```

## پورت‌های پیش‌فرض

| سرویس | Host | Container |
| --- | ---: | ---: |
| Nginx | `80` | `80` |
| MySQL | `13307` | `3306` |
| PostgreSQL | `15432` | `5432` |
| Redis | `16379` | `6379` |
| phpMyAdmin | `18080` | `80` |
| pgAdmin | `18081` | `80` |

به‌جز Nginx، پورت‌های منتشرشده به‌صورت پیش‌فرض فقط روی `127.0.0.1` bind شده‌اند.

## تنظیمات `.env`

مهم‌ترین متغیرها:

```env
UID=1000
GID=1000

COMPOSE_PROFILES=php82,php85,mysql,redis,node,mysql-ui
DOWNLOAD_SOURCE_PRESET=official

DOCKER_LIBRARY_PREFIX=docker.io/library/
DOCKER_NAMESPACE_PREFIX=docker.io/

DEBIAN_MIRROR=https://deb.debian.org/debian
DEBIAN_SECURITY_MIRROR=https://deb.debian.org/debian-security
COMPOSER_REPOSITORY=https://repo.packagist.org
NPM_REGISTRY=https://registry.npmjs.org/
NPM_STRICT_SSL=true
```

اطلاعات اتصال دیتابیس و پورت‌ها نیز در `.env` قابل تغییر هستند.

اگر محیط شما فقط local نیست یا چند نفر به آن دسترسی دارند، پسوردهای پیش‌فرض را تغییر دهید.

## دستورات کاربردی

نمایش سرویس‌های فعال:

```bash
docker compose ps
```

شروع استک:

```bash
docker compose up -d
```

build و start:

```bash
docker compose up -d --build
```

خاموش کردن بدون حذف volume دیتابیس:

```bash
docker compose down
```

مشاهده logها:

```bash
docker compose logs -f
```

بررسی Compose configuration:

```bash
docker compose config
```

بررسی Redis:

```bash
docker compose exec redis redis-cli ping
```

بررسی PostgreSQL:

```bash
docker compose exec postgres sh -lc 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

## امنیت داده‌ها

اطلاعات MySQL، PostgreSQL و pgAdmin در Docker volume نگهداری می‌شوند.

این دستور containerها را خاموش می‌کند ولی volumeها را حذف نمی‌کند:

```bash
docker compose down
```

اما این دستور مخرب است و volumeها را حذف می‌کند:

```bash
docker compose down -v
```

از گزینه `-v` فقط زمانی استفاده کنید که واقعاً قصد پاک کردن کامل داده‌های local را دارید.

## رفع اشکال

### پورت 80 اشغال است

سرویس یا container دیگری که از پورت 80 استفاده می‌کند را متوقف کنید یا mapping مربوط به Nginx را تغییر دهید.

### mirror منطقه‌ای image را پیدا نمی‌کند

باید بررسی شود که mirror انتخاب‌شده image upstream موردنظر را واقعاً proxy یا mirror می‌کند.

Dockavel هنگام انتخاب source منطقه‌ای به‌صورت عمدی fallback مخفی به registry دیگری انجام نمی‌دهد.

برای تغییر source دوباره اجرا کنید:

```bash
./setup.sh
```

و preset دیگری یا `Custom endpoints` را انتخاب کنید.

### اضافه کردن سرویس جدید

دوباره `./setup.sh` را اجرا کنید، سرویس‌های قبلی را انتخاب نگه دارید و سرویس جدید را اضافه کنید.

برای بررسی نتیجه:

```bash
grep '^COMPOSE_PROFILES=' .env
docker compose config
docker compose ps -a
```

## فایل‌های local و Git

این موارد عمداً commit نمی‌شوند:

```text
projects/*
nginx/conf.d/*
.env
```

به این ترتیب سورس پروژه‌های local، دامنه‌ها، credentialها و تنظیمات مخصوص هر سیستم وارد repository Dockavel نمی‌شوند.

## CI

GitHub Actions موارد زیر را بررسی می‌کند:

- چند ترکیب مختلف Compose profile
- build نسخه‌های PHP 8.2، 8.3، 8.4 و 8.5
- قابلیت‌های ضروری runtimeهای PHP
- build و runtime مربوط به Node.js 24
- syntax اسکریپت‌های Bash و POSIX shell

هدف این است که خطاهای Compose و runtime قبل از ورود تغییرات به `main` مشخص شوند.

## Roadmap

مرحله بعدی پروژه، مدیریت configuration هر پروژه به‌صورت مستقل است.

نمونه metadata آینده:

```yaml
name: ledger
local_domain: ledger.local
php: "8.5"
database: postgres
redis: true
node: false
```

فرمان برنامه‌ریزی‌شده:

```bash
./dockavel project:add
```

هدف این است که Dockavel در آینده Nginx config و runtime mapping هر پروژه را خودش تولید و مدیریت کند و نیاز به تنظیم دستی پروژه‌ها کمتر شود.

## مشارکت

Issue و Pull Request برای پروژه پذیرفته می‌شود.

در تغییرات مربوط به runtime، source، mirror یا installer بهتر است رفتار هر preset شفاف باقی بماند و dependency یا registry fallback مخفی اضافه نشود.

## License

MIT
