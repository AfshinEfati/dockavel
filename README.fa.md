# Dockavel

[![CI](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml/badge.svg)](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml)

[English](README.md) | **فارسی**

[وب‌سایت](https://afshinefati.github.io/dockavel-site/) · [مستندات](https://afshinefati.github.io/dockavel-site/docs/) · [راهنمای مشارکت](CONTRIBUTING.md)

Dockavel یک محیط توسعه محلی سبک و قابل تنظیم برای اجرای هم‌زمان چند پروژه **Laravel و Node.js** روی یک Docker Compose stack مشترک است.

هدف این است که چند پروژه با نسخه‌های متفاوت PHP، دیتابیس‌های مختلف، دامنه‌های محلی جدا و شرایط شبکه‌ای متفاوت را بدون ساختن یک استک تکراری برای هر پروژه مدیریت کنید. Dockavel عمداً Core کوچکی دارد: فقط سرویس‌های موردنیاز را فعال می‌کنید، پروژه‌ها را با CLI ساده مدیریت می‌کنید و تنظیمات اضافه‌ای که استفاده روزمره را پیچیده کند وارد هسته نمی‌شود.

## چرا Dockavel؟

یک فایل Compose ساده برای یک پروژه معمولاً کافی است، اما وقتی چند پروژه دارید مشکلاتی مثل این‌ها ایجاد می‌شود:

- یک پروژه PHP 8.2 می‌خواهد و پروژه دیگر PHP 8.5
- بعضی پروژه‌ها MySQL و بعضی PostgreSQL می‌خواهند
- چند پروژه به Redis یا Node.js مشترک نیاز دارند
- برای هر پروژه یک دامنه محلی جدا لازم است
- دسترسی مستقیم به registryها و repositoryهای جهانی همیشه پایدار نیست

Dockavel این زیرساخت را در یک محیط مشترک مدیریت می‌کند.

## اصول طراحی

Dockavel عمداً قرار نیست به یک استک شلوغ و همه‌کاره تبدیل شود.

یک قابلیت جدید وقتی وارد Core می‌شود که حداقل یکی از این کارها را انجام دهد:

1. راه‌اندازی پروژه را سریع‌تر کند،
2. مدیریت چند پروژه را ساده‌تر کند،
3. خطاها و زمان debug محیط توسعه را کمتر کند.

هدف، automation مفید با کمترین پیچیدگی ممکن است.

## امکانات

- اجرای هم‌زمان PHP-FPM نسخه‌های **8.2، 8.3، 8.4 و 8.5**
- MySQL 8 و PostgreSQL 17 به‌صورت اختیاری
- Redis 7 به‌صورت اختیاری
- Node.js 24 به‌صورت اختیاری
- phpMyAdmin و pgAdmin به‌صورت اختیاری
- Docker Compose Profiles برای فعال کردن فقط سرویس‌های لازم
- نصب‌کننده تعاملی `./setup.sh`
- CLI سراسری اختیاری با دستور `dockavel`
- shortcutهای ترمینال مثل `ds my-api`، `da my-api migrate`، `dco my-api install` و `dpl`
- presetهای دانلود برای Docker imageها و package repositoryها
- Official/Global، IranServer، Runflare، China و Custom
- عدم fallback مخفی بین registryها در presetهای منطقه‌ای
- مسیریابی Nginx برای هر پروژه و runtime
- پوشه مشترک `projects/` برای runtimeها
- Project Manager برای add/list/edit/remove
- دستورهای Project-aware شامل `shell`، `artisan`، `composer` و `npm`
- ابزار عیب‌یابی read-only با `dockavel doctor` یا `ddoc`
- تست read-only منبع دانلود با `dockavel source:test` یا `dsrc`
- تست خودکار Compose، runtimeها، shell scriptها، routing دستورهای پروژه و shortcutها در GitHub Actions
- عدم وابستگی به image خصوصی یا registry اختصاصی Dockavel

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

تمام runtimeهای پروژه پوشه زیر را mount می‌کنند:

```text
./projects → /var/www
```

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
| phpMyAdmin | image upstream | `mysql-ui` |
| pgAdmin | 9 | `postgres-ui` |
| Nginx | Alpine | همیشه فعال |

PHPها به‌صورت local از image عمومی زیر build می‌شوند:

```text
serversideup/php:<version>-fpm
```

Node.js نیز از این image عمومی build می‌شود:

```text
node:24-bookworm-slim
```

مسیر واقعی image بر اساس mirror انتخاب‌شده تغییر می‌کند.

برای اجرای Dockavel نیازی به Docker Hub account، GHCR account یا registry خصوصی Dockavel ندارید.

## پیش‌نیازها

- Docker Engine یا Docker Desktop
- Docker Compose v2 (`docker compose`)
- Bash
- ترمینال interactive
- آزاد بودن پورت `80` برای Nginx

در Windows استفاده از **WSL2** پیشنهاد می‌شود.

بررسی Docker:

```bash
docker --version
docker compose version
```

## نصب سریع

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
chmod +x setup.sh dockavel
./setup.sh
```

در اولین اجرا اگر `.env` وجود نداشته باشد از `.env.example` ساخته می‌شود.

setup از شما می‌خواهد این موارد را انتخاب کنید:

1. منبع دانلود
2. نسخه‌های PHP
3. دیتابیس‌ها
4. سرویس‌های اختیاری
5. ابزارهای مدیریت دیتابیس
6. نصب دستور global `dockavel` و shortcutها
7. build/start شدن استک

کلیدها:

- `↑` و `↓` برای جابه‌جایی
- `Space` برای انتخاب یا حذف انتخاب
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

نتیجه ممکن است این باشد:

```env
COMPOSE_PROFILES=php82,php85,mysql,postgres,redis,node,mysql-ui
```

وقتی Build and start را انتخاب کنید رفتار معادل این دستورات است:

```bash
docker compose pull --ignore-buildable
docker compose up -d --build
```

`--ignore-buildable` مانع می‌شود Compose سرویس‌های PHP و Node را که باید local build شوند به‌اشتباه مثل image آماده Dockavel pull کند.

## CLI سراسری و Shortcutها

در setup می‌توانید نصب دستور global و shortcutها را انتخاب کنید. بعداً هم دستی قابل نصب هستند:

```bash
./dockavel shortcuts:install
```

Dockavel symlinkهای مدیریت‌شده را در `~/.local/bin` می‌سازد. اگر این مسیر داخل `PATH` نباشد، یک block مشخص و idempotent به startup config مربوط به Bash یا Zsh اضافه می‌شود و دستور reload دقیق نمایش داده می‌شود.

بعد از نصب می‌توانید از هر مسیر اجرا کنید:

```bash
dockavel help
dockavel project:list
```

Shortcutهای روزمره:

```text
ds <project>             → dockavel shell <project>
da <project> ...         → dockavel artisan <project> ...
dco <project> ...        → dockavel composer <project> ...
dn <project> ...         → dockavel npm <project> ...
dpa                      → dockavel project:add
dpl                      → dockavel project:list
dpe <project>            → dockavel project:edit <project>
dpr <project>            → dockavel project:remove <project>
ddoc                     → dockavel doctor
dsrc                     → dockavel source:test
dh [command]             → dockavel help [command]
```

مثال:

```bash
ds my-api
da my-api migrate
dco my-api install
dn frontend run dev
dpl
dh artisan
```

عمداً از `ddoc` به‌جای `dd` استفاده شده چون `dd` یک command استاندارد Unix است.

Dockavel هیچ command یا فایل موجودی را overwrite نمی‌کند. نصب shortcutها idempotent است و اگر نامی از قبل وجود داشته باشد فقط conflict را گزارش می‌کند.

مدیریت shortcutها:

```bash
dockavel shortcuts:list
dockavel shortcuts:install
dockavel shortcuts:remove
```

`shortcuts:remove` فقط symlinkهای مدیریت‌شده توسط Dockavel را پاک می‌کند و PATH مربوط به `~/.local/bin` را دست نمی‌زند، چون ممکن است commandهای دیگری هم در آن مسیر وجود داشته باشند.

Help کامل ترمینال:

```bash
dockavel help
dockavel help shell
dh
dh composer
```

قبل از نصب shortcutها همه دستورها همچنان با `./dockavel` کار می‌کنند.

## منبع‌های دانلود

Dockavel منبع Docker image و package repositoryها را در قالب یک preset مدیریت می‌کند.

وقتی preset منطقه‌ای انتخاب می‌شود، Dockavel به‌صورت عمدی fallback مخفی به registry دیگری انجام نمی‌دهد.

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

نمونه base imageها از طریق mirror:

```text
docker.iranserver.com/serversideup/php:8.5-fpm
docker.iranserver.com/library/node:24-bookworm-slim
```

### Iran / Runflare

Docker، Debian، Composer و npm از mirrorهای Runflare استفاده می‌شوند. Availability و quota این سرویس توسط Runflare کنترل می‌شود و ممکن است تغییر کند.

### China / regional mirrors

- Docker: DaoCloud
- Debian: Tsinghua
- Composer: Aliyun
- npm: npmmirror

### Custom endpoints

در حالت Custom می‌توانید این مقادیر را تعیین کنید:

- Docker library prefix
- Docker namespace prefix
- Debian mirror
- Debian security mirror
- Composer repository
- npm registry
- npm strict SSL

مقادیر در `.env` ذخیره می‌شوند.

## Doctor: عیب‌یابی محیط

اجرا:

```bash
dockavel doctor
```

Doctor کاملاً **read-only** است. `.env`، Docker، DNS، mirrorها، containerها یا hosts سیستم را تغییر نمی‌دهد.

مواردی که فعلاً بررسی می‌کند:

- Docker CLI
- Docker daemon
- Docker Compose
- تشخیص WSL
- وجود `.env`
- وضعیت پورت 80
- preset دانلود انتخاب‌شده
- دسترسی به Docker registry
- دسترسی به Debian mirror
- دسترسی به Debian security mirror
- دسترسی به Composer repository
- دسترسی به npm registry
- HTTP status، زمان پاسخ و IP مقصد
- وضعیت سرویس‌های فعال
- health کانتینرهایی که healthcheck دارند

نمونه:

```text
Dockavel Doctor
===============

System
------
Docker CLI               ✅ Docker version ...
Docker daemon            ✅ reachable
Docker Compose           ✅ Docker Compose version ...
WSL                      ✅ detected
Port 80                  ✅ used by dockavel-nginx

Download source
---------------
Selected preset          ℹ️  iranserver
Docker registry          ✅ HTTP 401 · 0.37s · 185.x.x.x
Composer                 ✅ HTTP 200 · 0.34s · 185.x.x.x
npm                      ✅ HTTP 200 · 0.44s · 185.x.x.x
```

برای endpoint `/v2/` رجیستری Docker، پاسخ `HTTP 401` به معنی reachable بودن registry در نظر گرفته می‌شود چون ممکن است authentication لازم باشد.

اگر route پیش‌فرض fail شود Doctor یک retry فقط با IPv4 انجام می‌دهد تا مشکل route/IPv6 را تشخیص دهد؛ بدون اینکه تنظیم شبکه سیستم را تغییر دهد.

## تست منبع دانلود فعلی

```bash
dockavel source:test
```

این دستور فقط endpointهای موجود در `.env` را تست می‌کند و preset را تغییر نمی‌دهد.

برای شرایط اینترنت ناپایدار یا محدود، قبل از pull/build بزرگ مفید است.

## اضافه کردن سرویس به استک موجود

برای اضافه کردن سرویس لازم نیست کل محیط را حذف کنید.

دوباره اجرا کنید:

```bash
./setup.sh
```

انتخاب‌های قبلی را نگه دارید و سرویس جدید را اضافه کنید. Compose تا جای ممکن imageها، build cache، volumeها و containerهای بدون تغییر را reuse می‌کند.

اجرای مجدد setup باعث حذف volumeهای دیتابیس نمی‌شود.

## ساختار پروژه

```text
Dockavel/
├── projects/
│   ├── legacy-crm/
│   │   └── .dockavel.yml
│   ├── booking-api/
│   │   └── .dockavel.yml
│   └── frontend/
│       └── .dockavel.yml
├── lib/
│   ├── help.sh
│   ├── project-manager.sh
│   ├── project-commands.sh
│   └── shortcuts.sh
├── nginx/
│   ├── conf.d/
│   ├── template-laravel.conf.example
│   └── template-node.conf.example
├── Dockerfile
├── Dockerfile-node
├── docker-compose.yml
├── dockavel
├── setup.sh
└── .env
```

فایل‌های پروژه‌های local، Nginx configهای تولیدشده، `.dockavel.yml` داخل پروژه‌ها و `.env` machine-specific هستند و قرار نیست وارد repository اصلی Dockavel شوند.

## Project Manager

Project Manager یک پروژه **موجود** داخل `projects/` را register می‌کند. خودش پروژه Laravel یا Node جدید ایجاد نمی‌کند.

### افزودن پروژه

```bash
dockavel project:add
# یا: dpa
```

این دستور:

- Laravel را از `artisan` و `composer.json` تشخیص می‌دهد
- Node.js را از `package.json` تشخیص می‌دهد
- نام و دامنه local را می‌گیرد
- فقط PHP runtimeهایی را نشان می‌دهد که در Stack فعلی فعال‌اند
- فقط دیتابیس‌هایی را پیشنهاد می‌دهد که فعال‌اند
- در صورت موجود بودن Redis و Node درباره استفاده از آن‌ها سؤال می‌کند
- metadata پروژه را می‌سازد
- Nginx config را از templateهای موجود تولید می‌کند
- قبل از اعمال config، Nginx را validate می‌کند
- در صورت اجرا بودن Nginx آن را reload می‌کند
- اگر validation یا apply شکست بخورد فایل‌های ایجادشده را rollback می‌کند
- hosts سیستم را خودکار تغییر نمی‌دهد و فقط خط لازم را نمایش می‌دهد

نمونه metadata:

```yaml
version: 1
name: "my-api"
type: "laravel"
path: "my-api"
domain: "my-api.local"
php: "8.5"
database: "postgres"
redis: true
node: true
```

برای پروژه Node به‌جای PHP version، پورت داخلی برنامه ذخیره می‌شود.

### لیست پروژه‌ها

```bash
dpl
# یا: dockavel project:list
```

نمونه:

```text
NAME                 TYPE       DOMAIN                       RUNTIME        DATABASE
my-api               laravel    my-api.local                 PHP 8.5        postgres
frontend             node       frontend.local               Node :3000     none
```

### ویرایش پروژه

انتخاب interactive:

```bash
dockavel project:edit
```

یا مستقیم با نام پروژه:

```bash
dpe my-api
```

موارد قابل ویرایش:

- نام پروژه
- دامنه local
- PHP runtime برای Laravel
- دیتابیس
- استفاده از Redis
- استفاده از shared Node runtime
- پورت پروژه‌های Node.js

Path و Type پروژه هنگام edit ثابت می‌مانند.

بعد از edit، metadata و Nginx config دوباره تولید می‌شوند و در صورت fail شدن validation/reload، rollback انجام می‌شود.

### حذف registration پروژه

Interactive:

```bash
dockavel project:remove
```

مستقیم:

```bash
dpr my-api
```

`project:remove` فقط registration مربوط به Dockavel را حذف می‌کند:

```text
projects/my-api/.dockavel.yml
nginx/conf.d/my-api.local.conf
```

**سورس پروژه و پوشه پروژه هرگز حذف نمی‌شود.**

در صورت fail شدن Nginx validation/reload، فایل‌های Dockavel restore می‌شوند.

## دستورات Project-aware

بعد از register شدن پروژه، Dockavel می‌تواند دستورهای روزمره را با استفاده از metadata همان پروژه به runtime درست بفرستد:

```bash
ds my-api
da my-api migrate
dco my-api install
dn frontend install
```

### `shell`

برای پروژه Laravel، Bash داخل PHP runtime ثبت‌شده در `.dockavel.yml` باز می‌شود. برای پروژه Node، shell داخل runtime مشترک Node باز می‌شود.

```bash
ds legacy-api   # اگر php: "8.2" باشد → php82
ds my-api       # اگر php: "8.5" باشد → php85
ds frontend     # پروژه Node → node
```

### `artisan`

`php artisan` را داخل PHP runtime و working directory همان پروژه اجرا می‌کند:

```bash
da my-api migrate
da my-api queue:work
da my-api route:list
```

اجرای Artisan برای پروژه Node رد می‌شود.

### `composer`

Composer در همان PHP runtime ثبت‌شده پروژه اجرا می‌شود:

```bash
dco my-api install
dco my-api update
dco my-api require vendor/package
```

### `npm`

npm داخل runtime مشترک Node اجرا می‌شود. این دستور برای پروژه‌های Node و پروژه‌های Laravel که در metadata مقدار `node: true` دارند قابل استفاده است:

```bash
dn my-api install
dn my-api run build
dn frontend run dev
```

قبل از اجرای این دستورها Dockavel بررسی می‌کند runtime موردنیاز فعال و در حال اجرا باشد، پوشه پروژه روی host هنوز وجود داشته باشد و همان مسیر داخل runtime انتخاب‌شده هم قابل مشاهده باشد.

اگر Docker Desktop/WSL دچار stale bind mount شده باشد و پروژه روی host وجود داشته باشد ولی داخل container دیده نشود، Dockavel قبل از اجرای Artisan، Composer، npm یا shell متوقف می‌شود و مشکل visibility/mount را اعلام می‌کند.

تمام argumentهای بعد از نام پروژه مستقیم به command اصلی پاس داده می‌شوند و داخل یک shell اضافه wrap نمی‌شوند.

## فایل hosts

Dockavel عمداً hosts سیستم host را خودکار تغییر نمی‌دهد.

بعد از ثبت پروژه، خط نمایش‌داده‌شده را اضافه کنید. مثال:

```text
127.0.0.1 my-api.local
```

در Windows فایل hosts اینجاست:

```text
C:\Windows\System32\drivers\etc\hosts
```

برای ذخیره معمولاً باید editor را با Administrator باز کنید.

## اجرای چند نسخه PHP به‌صورت هم‌زمان

مثال:

```text
projects/
├── old-app/       # PHP 8.2
├── internal-api/  # PHP 8.4
└── new-app/       # PHP 8.5
```

Nginx هر پروژه را به runtime انتخاب‌شده وصل می‌کند:

```text
php82:9000
php84:9000
php85:9000
```

تمام runtimeهای فعال می‌توانند هم‌زمان بالا باشند.

## دستورات PHP و Composer

برای پروژه‌های register‌شده مسیر معمول استفاده از shortcutهای Project-aware است:

```bash
ds my-api
da my-api migrate
dco my-api install
```

برای بررسی‌های low-level همچنان می‌توانید مستقیم از Compose استفاده کنید:

```bash
docker compose exec php82 php -v
docker compose exec php85 php -v
docker compose exec php85 bash
```

تفاوت نام‌ها:

```text
Compose service : php85
Container name  : dockavel-php85
Local image     : dev-stack-php85
```

در استفاده low-level بهتر است service name مربوط به Compose را استفاده کنید، نه container name را.

## پروژه‌های Node.js

برای پروژه Node ثبت‌شده یا Laravel با Node فعال:

```bash
dn frontend install
dn frontend run dev
ds frontend
```

برای بررسی مستقیم runtime مشترک:

```bash
docker compose exec node node --version
docker compose exec node npm --version
```

پروژه Node ثبت‌شده در Project Manager از پورت داخلی محدوده `3000-3099` استفاده می‌کند و از طریق Nginx در دسترس قرار می‌گیرد.

## MySQL

داخل Docker:

```text
mysql:3306
```

روی host:

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

Volume دائمی: `mysql_data`.

## PostgreSQL

داخل Docker:

```text
postgres:5432
```

روی host:

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

Volume دائمی: `postgres_data`.

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

Server: `mysql`

### pgAdmin

اگر `postgres-ui` فعال باشد:

```text
http://127.0.0.1:18081
```

اتصال:

```text
Host: postgres
Port: 5432
```

Volume دائمی: `pgadmin_data`.

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

## تنظیمات مهم `.env`

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

credentialهای دیتابیس و پورت‌ها نیز در `.env` قابل تغییرند.

## دستورات کاربردی

```bash
# Help
dockavel help
dh

# عیب‌یابی Dockavel
ddoc
dsrc

# مدیریت پروژه‌ها
dpa
dpl
dpe my-api
dpr my-api

# دستورهای Project-aware
ds my-api
da my-api migrate
dco my-api install
dn frontend install

# مدیریت shortcutها
dockavel shortcuts:list
dockavel shortcuts:install
dockavel shortcuts:remove

# وضعیت Stack
docker compose ps

# Start / Build
docker compose up -d
docker compose up -d --build

# Stop بدون حذف volumeها
docker compose down

# Logها
docker compose logs -f

# Validate Compose
docker compose config
```

## امنیت داده‌ها

داده‌های دیتابیس در Docker volumeهای named نگهداری می‌شوند.

این دستور volumeها را حذف نمی‌کند:

```bash
docker compose down
```

این دستور مخرب است و volumeها را حذف می‌کند:

```bash
docker compose down -v
```

از `-v` فقط زمانی استفاده کنید که واقعاً قصد پاک کردن داده‌های local را دارید.

`project:remove` متفاوت است: فقط metadata و Nginx registration را حذف می‌کند و هرگز سورس پروژه را پاک نمی‌کند.

## رفع اشکال

### قبل از rebuild عیب‌یابی کنید

اول اجرا کنید:

```bash
ddoc
```

برای تست فقط sourceها:

```bash
dsrc
```

این کار کمک می‌کند مشکل Docker/project را از DNS، TLS، timeout، mirror یا route جدا کنید و بی‌دلیل وارد rebuildهای سنگین نشوید.

### پورت 80 اشغال است

Doctor مشخص می‌کند پورت 80 آزاد است، توسط `dockavel-nginx` استفاده می‌شود یا سرویس دیگری آن را گرفته است.

### mirror منطقه‌ای image را پیدا نمی‌کند

بررسی کنید mirror انتخاب‌شده واقعاً image upstream را proxy/mirror می‌کند. Dockavel برای preset منطقه‌ای fallback مخفی به registry دیگر انجام نمی‌دهد.

در صورت نیاز `./setup.sh` را دوباره اجرا کنید و preset دیگری یا `Custom endpoints` را صریح انتخاب کنید.

### پروژه روی host هست ولی داخل runtime دیده نمی‌شود

دستورهای Project-aware قبل از اجرا visibility مسیر پروژه را داخل runtime بررسی می‌کنند. اگر Docker Desktop/WSL دچار stale bind mount شود، Dockavel به‌جای اجرای command در وضعیت اشتباه خطای mount/visibility می‌دهد. وقتی مسیر host صحیح است، restart کردن Docker Desktop می‌تواند این وضعیت stale را برطرف کند.

### اضافه کردن سرویس بدون حذف استک

```bash
./setup.sh
```

سرویس‌های قبلی را انتخاب نگه دارید و سرویس جدید را اضافه کنید.

### بررسی وضعیت فعلی

```bash
grep '^COMPOSE_PROFILES=' .env
docker compose config
docker compose ps -a
dpl
```

## فایل‌های Local و Git

موارد زیر عمداً machine-specific هستند:

```text
projects/*
nginx/conf.d/*
.env
```

به این ترتیب سورس پروژه‌های local، دامنه‌ها، credentialها و تنظیمات هر سیستم وارد repository اصلی Dockavel نمی‌شوند.

## CI

GitHub Actions فعلاً این موارد را بررسی می‌کند:

- چند ترکیب مختلف Compose profile
- build نسخه‌های PHP 8.2، 8.3، 8.4 و 8.5
- قابلیت‌های ضروری PHP runtimeها
- build/runtime مربوط به Node.js 24
- syntax مربوط به `setup.sh`، `dockavel`، Project Manager، Project Commands، Help و Shortcuts
- routing دستورهای Project-aware با Docker mock
- نصب/حذف global shortcutها و resolve شدن symlinkها
- executable بودن CLI اصلی

## Roadmap

پایه‌های اصلی تکمیل‌شده:

```text
✅ Configurable stack
✅ Multiple PHP runtimes
✅ Regional download sources
✅ MySQL / PostgreSQL / Redis / Node
✅ Doctor / source diagnostics
✅ Project add / list / edit / remove
✅ Project-aware shell / Artisan / Composer / npm
✅ Global Dockavel CLI / Help / terminal shortcuts
```

گزینه‌های منطقی بعدی:

```text
- تشخیص هوشمندتر پروژه و پیشنهاد runtime
- Database Helperها برای workflowهای تکراری local
- بهبود بیشتر Doctor و Project Health diagnostics
```

این موارد هنوز featureهای جدا هستند و قرار نیست automation مخفی یا تصمیم‌گیری غیرشفاف وارد Dockavel کنند.

## مشارکت

Issue و Pull Request پذیرفته می‌شود. راهنمای کامل در [CONTRIBUTING.md](CONTRIBUTING.md) قرار دارد.

هر قابلیت، سرویس، runtime، source preset، دستور CLI، تنظیم، پورت، workflow یا تغییر رفتار قابل مشاهده برای کاربر باید هم‌زمان در READMEهای انگلیسی/فارسی و [وب‌سایت و مستندات عمومی Dockavel](https://afshinefati.github.io/dockavel-site/docs/) به‌روزرسانی شود.

در تغییرات مربوط به runtime، source، mirror، installer یا Project Manager رفتار presetها باید شفاف بماند و dependency یا registry fallback مخفی اضافه نشود.

## License

MIT
