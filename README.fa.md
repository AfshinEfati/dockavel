# Dockavel

[![CI](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml/badge.svg)](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml)

[English](README.md) | **فارسی**

[وب‌سایت](https://afshinefati.github.io/dockavel-site/) · [مستندات](https://afshinefati.github.io/dockavel-site/docs/) · [راهنمای مشارکت](CONTRIBUTING.md)

Dockavel یک محیط توسعه محلی سبک و قابل تنظیم برای اجرای هم‌زمان چند پروژه **Laravel و Node.js** روی یک Docker Compose stack مشترک است.

هدف این است که توسعه‌دهنده برای استفاده روزمره از پروژه‌های Docker-based مجبور نباشد اسم containerها، serviceها و دستورهای طولانی Docker Compose را حفظ کند.

## چرا Dockavel؟

وقتی چند پروژه دارید معمولاً با این مسائل روبه‌رو می‌شوید:

- یک پروژه PHP 8.2 می‌خواهد و پروژه دیگر PHP 8.5
- بعضی پروژه‌ها MySQL و بعضی PostgreSQL می‌خواهند
- چند پروژه به Redis یا Node.js مشترک نیاز دارند
- برای هر پروژه دامنه local جدا لازم است
- دسترسی به registryها و repositoryهای جهانی همیشه پایدار نیست
- توسعه‌دهنده نباید برای کارهای روزمره مجبور به حفظ کردن Docker commandهای طولانی باشد

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
- Official/Global، IranServer، Runflare، China و Custom sourceها
- عدم fallback مخفی بین registryها در presetهای منطقه‌ای
- Nginx routing برای هر پروژه و runtime
- Project Manager برای add/list/edit/remove
- دستورهای project-aware برای shell، Artisan، Composer و npm
- نصب اختیاری دستور global به شکل `dockavel` بدون نیاز به `./dockavel`
- shortcutهای کوتاه مثل `ds`، `da`، `dco`، `dn` و `dpl`
- Help کامل با `dockavel help`، دستور `dh` و help اختصاصی هر command
- Diagnostics read-only با `dockavel doctor`
- تست sourceها با `dockavel source:test`
- CI برای runtimeها، Compose، shell scriptها، project commandها و shortcutها
- بدون نیاز به Docker Hub account، GHCR account یا image خصوصی Dockavel

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
   ├── MySQL 8       (optional)
   ├── PostgreSQL 17 (optional)
   ├── Redis 7       (optional)
   └── Node.js 24    (optional)
```

تمام runtimeهای پروژه این مسیر را mount می‌کنند:

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
| phpMyAdmin | upstream image | `mysql-ui` |
| pgAdmin | 9 | `postgres-ui` |
| Nginx | Alpine | همیشه فعال |

PHP runtimeها از image عمومی `serversideup/php:<version>-fpm` و Node.js از `node:24-bookworm-slim` build می‌شوند و source واقعی بر اساس mirror انتخاب‌شده تغییر می‌کند.

## پیش‌نیازها

- Docker Engine یا Docker Desktop
- Docker Compose v2
- Bash
- ترمینال interactive
- آزاد بودن پورت `80`

در Windows استفاده از **WSL2** پیشنهاد می‌شود.

## نصب سریع

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
chmod +x setup.sh dockavel
./setup.sh
```

Setup از شما source، نسخه‌های PHP، دیتابیس‌ها، سرویس‌های اختیاری، ابزارهای دیتابیس، نصب global CLI/shortcutها و build/start شدن استک را می‌پرسد.

اگر نصب shortcutها را تأیید کنید، Dockavel symlinkهای مدیریت‌شده را داخل `~/.local/bin` ایجاد می‌کند. اگر این مسیر در `PATH` نباشد، یک block مشخص و idempotent به startup file مربوط به Bash یا Zsh اضافه می‌شود و دستور reload دقیق نمایش داده می‌شود.

بعد از reload کردن shell، استفاده روزمره به این شکل می‌شود:

```bash
dockavel help
dpl
ds my-api
da my-api route:list
```

یعنی برای استفاده عادی دیگر `./dockavel` لازم نیست.

## Global CLI، Help و Shortcutها

نصب یا refresh کردن commandهای global:

```bash
./dockavel shortcuts:install
```

نمایش وضعیت:

```bash
dockavel shortcuts:list
```

حذف shortcutهایی که فقط توسط همین checkout ساخته شده‌اند:

```bash
dockavel shortcuts:remove
```

Dockavel هیچ فایل یا command موجودی را overwrite نمی‌کند. برای Doctor عمداً از `ddoc` استفاده شده و نه `dd`، چون `dd` یک command استاندارد Unix است.

### Help کامل

```bash
dockavel help
dh
```

Help یک command خاص:

```bash
dockavel help shell
dh artisan
dh shortcuts
```

### جدول Shortcutها

| Shortcut | دستور معادل |
| --- | --- |
| `ds <project>` | `dockavel shell <project>` |
| `da <project> ...` | `dockavel artisan <project> ...` |
| `dco <project> ...` | `dockavel composer <project> ...` |
| `dn <project> ...` | `dockavel npm <project> ...` |
| `dpa` | `dockavel project:add` |
| `dpl` | `dockavel project:list` |
| `dpe <project>` | `dockavel project:edit <project>` |
| `dpr <project>` | `dockavel project:remove <project>` |
| `ddoc` | `dockavel doctor` |
| `dsrc` | `dockavel source:test` |
| `dh [command]` | `dockavel help [command]` |

مثال:

```bash
ds testlara
da testlara migrate
da testlara route:list
dco testlara install
dn testlara run dev
dpl
ddoc
```

Command global و shortcutها به فایل واقعی `dockavel` داخل checkout وصل می‌شوند. CLI قبل از load کردن Compose و metadata، symlink را resolve می‌کند؛ بنابراین از هر مسیر کاری می‌توانید commandها را اجرا کنید.

## Source Presetها

Dockavel source مربوط به Docker imageها و package repositoryها را یکجا مدیریت می‌کند و fallback مخفی انجام نمی‌دهد.

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

### Iran / Runflare

از mirrorهای Docker، Debian، Composer و npm مربوط به Runflare استفاده می‌کند. Availability و quota این سرویس توسط Runflare کنترل می‌شود.

### China

از DaoCloud برای Docker، Tsinghua برای Debian، Aliyun برای Composer و npmmirror برای npm استفاده می‌شود.

### Custom

در حالت Custom می‌توانید endpointهای Docker، Debian، Composer و npm را صریحاً تنظیم کنید. مقادیر در `.env` ذخیره می‌شوند.

## Doctor و Source Diagnostics

```bash
dockavel doctor
# shortcut
ddoc
```

Doctor کاملاً read-only است و Docker CLI/daemon، Compose، WSL، `.env`، پورت 80، sourceها، سرویس‌های فعال و health containerها را بررسی می‌کند.

برای تست فقط sourceها:

```bash
dockavel source:test
# shortcut
dsrc
```

Probeها HTTP status، زمان پاسخ و IP مقصد را نمایش می‌دهند و اگر route پیش‌فرض fail شود یک IPv4 retry برای تشخیص انجام می‌شود.

## تغییر مرحله‌ای Stack

برای اضافه یا کم کردن سرویس‌های اختیاری دوباره اجرا کنید:

```bash
./setup.sh
```

Compose تا جای ممکن imageها، build cache، volumeها و containerهای بدون تغییر را reuse می‌کند. اجرای setup دیتای persistent دیتابیس را پاک نمی‌کند.

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
│   ├── project-manager.sh
│   ├── project-commands.sh
│   ├── shortcuts.sh
│   └── help.sh
├── nginx/
├── docker-compose.yml
├── dockavel
├── setup.sh
└── .env
```

پروژه‌های local، Nginx configهای تولیدشده، `.dockavel.yml` و `.env` machine-specific هستند.

## Project Manager

مسیر کوتاه برای استفاده روزمره:

```bash
dpa               # ثبت پروژه
dpl               # لیست پروژه‌ها
dpe my-api        # ویرایش پروژه
dpr my-api        # حذف registration
```

فرم کامل:

```bash
dockavel project:add
dockavel project:list
dockavel project:edit my-api
dockavel project:remove my-api
```

Project Manager پروژه موجود داخل `projects/` را register می‌کند، Laravel و Node.js را تشخیص می‌دهد، فقط runtime/serviceهای فعال را پیشنهاد می‌دهد، `.dockavel.yml` و Nginx config می‌سازد، قبل از apply کردن Nginx را validate می‌کند و در صورت fail شدن rollback انجام می‌دهد.

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

`project:remove` هرگز سورس پروژه را حذف نمی‌کند.

## دستورهای Project-aware

مسیر کوتاه پیشنهادی:

```bash
ds my-api
da my-api migrate
dco my-api install
dn my-api run dev
```

فرم کامل:

```bash
dockavel shell my-api
dockavel artisan my-api migrate
dockavel composer my-api install
dockavel npm my-api run dev
```

برای Laravel، `shell`، `artisan` و `composer` به‌صورت خودکار از PHP runtime ثبت‌شده در `.dockavel.yml` استفاده می‌کنند. پروژه Node از shared Node runtime استفاده می‌کند و `npm` برای پروژه Node یا Laravel با `node: true` فعال است.

قبل از اجرا، Dockavel بررسی می‌کند runtime فعال و running باشد، پروژه روی host وجود داشته باشد و مسیر پروژه داخل container دیده شود. اگر bind mount مربوط به Docker Desktop/WSL stale شده باشد، قبل از اجرای command خطای واضح نمایش داده می‌شود.

## فایل hosts

Dockavel فایل hosts سیستم را خودکار تغییر نمی‌دهد. بعد از ثبت پروژه، entry نمایش‌داده‌شده را دستی اضافه کنید:

```text
127.0.0.1 my-api.local
```

در Windows:

```text
C:\Windows\System32\drivers\etc\hosts
```

## دستورهای Low-level

کاربر عادی بهتر است از shortcutهای Dockavel استفاده کند. در صورت نیاز commandهای خام Compose همچنان در دسترس‌اند:

```bash
docker compose exec php82 php -v
docker compose exec php85 bash
docker compose exec node node --version
```

## اتصال سرویس‌ها

| سرویس | داخل Docker | روی Host |
| --- | --- | --- |
| MySQL | `mysql:3306` | `127.0.0.1:13307` |
| PostgreSQL | `postgres:5432` | `127.0.0.1:15432` |
| Redis | `redis:6379` | `127.0.0.1:16379` |
| phpMyAdmin | — | `127.0.0.1:18080` |
| pgAdmin | — | `127.0.0.1:18081` |

`docker compose down` volumeهای دیتابیس را نگه می‌دارد. `docker compose down -v` مخرب است و volumeها را حذف می‌کند.

## دستورهای کاربردی

```bash
# Help
dh
dh shell

# مدیریت پروژه
dpa
dpl
dpe my-api
dpr my-api

# commandهای پروژه
ds my-api
da my-api route:list
dco my-api install
dn my-api run dev

# Diagnostics
ddoc
dsrc

# مدیریت shortcutها
dockavel shortcuts:list
dockavel shortcuts:install
dockavel shortcuts:remove
```

## رفع اشکال

اول اجرا کنید:

```bash
ddoc
```

برای sourceها:

```bash
dsrc
```

اگر پروژه روی host وجود دارد اما داخل runtime دیده نمی‌شود، Dockavel command پروژه را اجرا نمی‌کند و مشکل bind mount را گزارش می‌دهد. اگر path صحیح باشد، restart کردن Docker Desktop می‌تواند stale bind mount را برطرف کند.

## CI

GitHub Actions فعلاً این موارد را بررسی می‌کند:

- چند ترکیب مختلف Compose profile
- build نسخه‌های PHP 8.2 تا 8.5
- قابلیت‌های ضروری PHP runtimeها
- Node.js 24
- syntax مربوط به setup، CLI، Project Manager، Project Commands، Help و Shortcuts
- routing commandهای project-aware با Docker mock
- symlink global، جلوگیری از overwrite، idempotent بودن PATH، aliasهای Help و حذف امن shortcutها

## Roadmap

موارد تکمیل‌شده:

```text
✅ Configurable stack
✅ Multiple PHP runtimes
✅ Regional download sources
✅ MySQL / PostgreSQL / Redis / Node
✅ Doctor / source diagnostics
✅ Project add / list / edit / remove
✅ Project-aware shell / Artisan / Composer / npm
✅ Global dockavel CLI + terminal shortcuts + full help
```

مراحل بعدی احتمالی:

```text
- تشخیص هوشمندتر پروژه و پیشنهاد runtime
- Database Helperها برای workflowهای تکراری
- Diagnostics بیشتر برای Doctor و Project Health
```

## مشارکت

Issue و Pull Request پذیرفته می‌شود. راهنمای کامل در [CONTRIBUTING.md](CONTRIBUTING.md) قرار دارد.

هر قابلیت user-facing باید هم‌زمان در READMEهای انگلیسی/فارسی و [وب‌سایت و مستندات عمومی Dockavel](https://afshinefati.github.io/dockavel-site/docs/) به‌روزرسانی شود.

## License

MIT
