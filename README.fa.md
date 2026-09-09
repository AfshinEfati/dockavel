# Dockavel

[![CI](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml/badge.svg)](https://github.com/AfshinEfati/dockavel/actions/workflows/ci.yml)

[English](README.md) | **فارسی**

[وب‌سایت](https://afshinefati.github.io/dockavel-site/) · [مستندات](https://afshinefati.github.io/dockavel-site/docs/) · [Workflowهای هوشمند](https://afshinefati.github.io/dockavel-site/docs/workflows/) · [راهنمای مشارکت](CONTRIBUTING.md)

Dockavel یک محیط توسعه محلی سبک برای اجرای چند پروژه **Laravel و Node.js** روی یک Docker Compose stack مشترک است. چند نسخه PHP می‌توانند همزمان اجرا شوند، Nginx هر پروژه را به runtime درست route می‌کند و CLI پروژه‌محور باعث می‌شود برای کارهای روزمره لازم نباشد دستورهای Docker را حفظ کنی.

هسته پروژه عمداً کوچک می‌ماند: اتوماسیون کاربردی، تنظیمات شفاف و بدون رفتار زیرساختی مخفی.

## وضعیت فعلی

نسخه توسعه فعلی:

```bash
dockavel version
# یا
dv
```

```text
0.1.0-dev
```

فایل‌های `VERSION` و `CHANGELOG.md` به مخزن اضافه شده‌اند. ساخت Tag یا GitHub Release عمومی، مرحله‌ای جدا از این نسخه توسعه است.

## قابلیت‌های اصلی

- اجرای همزمان PHP-FPM **8.2، 8.3، 8.4 و 8.5**
- MySQL 8 و PostgreSQL 17
- Redis 7
- Node.js 24
- phpMyAdmin و pgAdmin
- Compose Profile برای فعال بودن فقط سرویس‌های موردنیاز
- workspace مشترک `projects/`
- routing پروژه‌ها از طریق Nginx و runtime مخصوص هر پروژه
- Sourceهای شفاف Official، IranServer، Runflare، China و Custom
- ثبت پروژه با `.dockavel.yml`
- دستورات project-aware برای Shell، Artisan، Composer و npm
- دستور global `dockavel` و Shortcutهای ترمینال
- Smart Project Detection با پیشنهادهای شفاف
- Project Health Check
- Helperهای امن MySQL/PostgreSQL برای status/create/export/import
- Doctor و Source Diagnostics به‌صورت read-only
- CI برای runtimeها، Compose، routing دستورات، Detection، Database Helperها و Shortcutها
- بدون نیاز به Docker image خصوصی مخصوص Dockavel

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
   ├── MySQL 8
   ├── PostgreSQL 17
   ├── Redis 7
   └── Node.js 24
```

همه runtimeهای اپلیکیشن این مسیر را mount می‌کنند:

```text
./projects → /var/www
```

## استک پشتیبانی‌شده

| Component | Version / Type | Compose profile |
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

Runtimeهای PHP به‌صورت محلی از image عمومی `serversideup/php:<version>-fpm` و از طریق Docker namespace/mirror انتخاب‌شده build می‌شوند. Node.js نیز از `node:24-bookworm-slim` و mirror انتخاب‌شده build می‌شود.

برای اجرای Dockavel نیازی به Docker Hub account، GHCR account یا registry خصوصی Dockavel نیست.

## پیش‌نیازها

- Docker Engine یا Docker Desktop
- Docker Compose v2 (`docker compose`)
- Bash
- ترمینال تعاملی
- آزاد بودن پورت `80` برای Nginx

روی Windows استفاده داخل WSL2 پیشنهاد می‌شود.

## ورودی فعلی Setup

اسکریپت فعلی Setup همچنان این است:

```bash
git clone https://github.com/AfshinEfati/dockavel.git
cd dockavel
chmod +x setup.sh dockavel
./setup.sh
```

این اسکریپت Source فعلی، Profileهای فعال و نصب اختیاری Shortcutها را مدیریت می‌کند. UX اینستالر از معماری runtime جدا نگه داشته شده تا در آینده بتوان روش نصب را بدون تغییر مدل Stack جایگزین یا بازطراحی کرد.

برای اضافه کردن سرویس جدید به‌صورت معمول نیازی به حذف Volumeهای دیتابیس نیست.

## Global CLI و Shortcutها

یک‌بار Global CLI و Shortcutهای مدیریت‌شده را نصب کن:

```bash
./dockavel shortcuts:install
```

بعد از هر مسیری می‌توانی Dockavel را اجرا کنی:

```bash
dockavel help
dpl
ds my-api
```

Shortcutهای فعلی:

```text
ds <project>                    dockavel shell <project>
da <project> <args...>          dockavel artisan <project> <args...>
dco <project> <args...>         dockavel composer <project> <args...>
dn <project> <args...>          dockavel npm <project> <args...>

dpa                             dockavel project:add
dpl                             dockavel project:list
dpe <project>                   dockavel project:edit <project>
dpr <project>                   dockavel project:remove <project>
dpd <directory>                 dockavel project:detect <directory>
dpc <project>                   dockavel project:check <project>

dbs <project>                   dockavel db:status <project>
dbc <project>                   dockavel db:create <project>
dbx <project> [file.sql]        dockavel db:export <project> [file.sql]
dbi <project> <file.sql>        dockavel db:import <project> <file.sql>

ddoc                            dockavel doctor
dsrc                            dockavel source:test
dv                              dockavel version
dh [command]                    dockavel help [command]
```

Dockavel هیچ command یا فایل موجودی با نام مشابه Shortcut را overwrite نمی‌کند. symlinkهای مدیریت‌شده در `~/.local/bin` قرار می‌گیرند.

Help کامل:

```bash
dh
dh shell
dh project:detect
dh project:check
dh database
```

به‌جای `dd` از `ddoc` استفاده می‌شود چون `dd` یک دستور استاندارد Unix است.

## Project Manager

Project Manager یک پروژه **موجود** داخل `projects/` را ثبت می‌کند؛ خودش Laravel یا Node application جدید نمی‌سازد.

```bash
dpa
```

فرآیند Registration شامل این موارد است:

- تشخیص Laravel/Node
- نام پروژه و دامنه محلی
- انتخاب PHP runtime برای Laravel
- انتخاب MySQL/PostgreSQL در صورت فعال بودن
- Redis و shared Node flags
- ساخت `.dockavel.yml`
- ساخت و validate کردن Nginx config
- reload کردن Nginx در صورت running بودن
- rollback در صورت خطا در config تولیدشده
- نمایش hosts entry بدون تغییر خودکار فایل hosts سیستم‌عامل

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

دستورات دیگر Project Manager:

```bash
dpl
dpe my-api
dpr my-api
```

`project:remove` فقط Registration مربوط به Dockavel را حذف می‌کند و هیچ‌وقت سورس پروژه را پاک نمی‌کند.

## Smart Project Detection

بدون تغییر دادن پروژه، اطلاعات پیشنهادی آن را بررسی کن:

```bash
dockavel project:detect my-api
# Shortcut
dpd my-api
```

Detection فایل‌هایی مثل این‌ها را بررسی می‌کند:

- `artisan`
- `composer.json`
- `package.json`
- lockfileهای npm/yarn/pnpm/bun
- `.env` یا `.env.example`

خروجی می‌تواند شامل این موارد باشد:

- نوع Laravel یا Node.js
- PHP requirement از `composer.json`
- اولین PHP runtime فعال و سازگار به‌عنوان پیشنهاد
- تشخیص npm / yarn / pnpm / bun
- hint مربوط به MySQL / PostgreSQL / SQLite
- hint استفاده از Redis
- وجود Node frontend

Detection فقط پیشنهاد می‌دهد. `project:add` همچنان قبل از ذخیره metadata یا انتخاب runtime/service از کاربر سؤال می‌کند.

## دستورات Project-aware

بعد از Registration، Dockavel runtime و working directory پروژه را خودش resolve می‌کند:

```bash
ds my-api
da my-api migrate
dco my-api install
dn my-api run dev
```

برای Laravel، دستورات Shell، Artisan و Composer از PHP runtime ثبت‌شده در `.dockavel.yml` استفاده می‌کنند. پروژه Node از runtime مشترک Node استفاده می‌کند. `npm` هم برای پروژه Node و Laravelهایی که `node: true` دارند فعال است.

قبل از اجرا، Dockavel فعال/running بودن runtime، وجود مسیر پروژه روی Host و دیده شدن پروژه داخل Container را بررسی می‌کند.

## Project Health Check

یک پروژه ثبت‌شده را بدون تغییر بررسی کن:

```bash
dockavel project:check my-api
# Shortcut
dpc my-api
```

موارد بررسی‌شده:

- فیلدهای اصلی metadata
- مسیر پروژه روی Host
- markerهای Laravel/Node
- وضعیت PHP/Node runtime
- دیده شدن bind mount داخل runtime
- Nginx config و `server_name`
- اجرای `nginx -t` در صورت running بودن Nginx
- وجود دیتابیس تنظیم‌شده
- وضعیت Redis اختیاری
- وضعیت Node frontend اختیاری

Warningها از Failureهای واقعی جدا گزارش می‌شوند.

## Database Helperها

Database Helperها Project-aware هستند. نوع دیتابیس از `.dockavel.yml` و نام دیتابیس از `DB_DATABASE` داخل `.env` یا `.env.example` پروژه خوانده می‌شود.

بررسی وضعیت:

```bash
dbs my-api
```

ساخت دیتابیس در صورت نبودن:

```bash
dbc my-api
```

Export:

```bash
dbx my-api
# یا
dbx my-api backups/my-api.sql
```

Export هیچ فایل موجودی را overwrite نمی‌کند.

Import:

```bash
dbi my-api backups/my-api.sql
```

Import نیاز به تأیید صریح دارد چون SQL import ممکن است داده‌های موجود را تغییر دهد یا حذف کند.

Helperهای فعلی MySQL و PostgreSQL را پشتیبانی می‌کنند. دستور خودکار `drop` یا `reset` عمداً در این لایه وجود ندارد.

## Doctor و Source Diagnostics

اجرا:

```bash
ddoc
```

Doctor کاملاً read-only است و محیط Docker/WSL، Sourceهای تنظیم‌شده و سرویس‌های فعال را بررسی می‌کند. همچنین hintهای Registry و Proxy را گزارش می‌کند، از جمله:

- تعداد پروژه‌های ثبت‌شده و Registrationهای stale
- متغیرهای `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` در Shell
- وجود `proxies` block در `~/.docker/config.json`

Doctor هیچ Proxy، DNS، Docker Desktop setting، `.env`، mirror یا Containerی را تغییر نمی‌دهد.

برای تست فقط Sourceها:

```bash
dsrc
```

تست Source شامل Docker registry، Debian mirror، Composer repository و npm registry است و HTTP status، زمان پاسخ، remote IP و hint مربوط به IPv4 retry را گزارش می‌کند.

## Download Source Presetها

Dockavel Sourceهای image/package را شفاف نگه می‌دارد و preset منطقه‌ای به‌صورت مخفی به Source جهانی fallback نمی‌کند.

### Official / Global

```text
Docker     docker.io
Debian     deb.debian.org
Composer   repo.packagist.org
npm        registry.npmjs.org
```

### Iran / IranServer

```text
Docker library     docker.iranserver.com/library/
Docker namespace   docker.iranserver.com/
Debian              mirror.iranserver.com
Composer            composer.iranserver.com
npm                 npm.iranserver.com
```

### Iran / Runflare

از endpointهای Docker، Debian، Composer و npm مربوط به Runflare استفاده می‌کند.

### China

از endpointهای منطقه‌ای Docker، Debian، Composer و npm تنظیم‌شده در preset چین استفاده می‌کند.

### Custom

امکان تنظیم صریح Docker prefixes، Debian mirrors، Composer repository، npm registry و npm strict-SSL را می‌دهد.

## پورت‌های پیش‌فرض Host

| Service | Host | Container |
| --- | ---: | ---: |
| Nginx | `80` | `80` |
| MySQL | `13307` | `3306` |
| PostgreSQL | `15432` | `5432` |
| Redis | `16379` | `6379` |
| phpMyAdmin | `18080` | `80` |
| pgAdmin | `18081` | `80` |

به‌جز Nginx، پورت‌های منتشرشده به‌صورت پیش‌فرض روی `127.0.0.1` bind می‌شوند.

## Hosts File

Dockavel فایل hosts سیستم‌عامل را خودکار تغییر نمی‌دهد.

نمونه:

```text
127.0.0.1 my-api.local
```

در Windows:

```text
C:\Windows\System32\drivers\etc\hosts
```

## ایمنی داده

داده‌های پایدار دیتابیس داخل Docker named volumeها نگهداری می‌شوند.

خاموش کردن عادی و امن:

```bash
docker compose down
```

دستور destructive:

```bash
docker compose down -v
```

از `-v` فقط وقتی استفاده کن که واقعاً قصد حذف Volumeهای پایدار را داری.

Database Import با Confirmation محافظت می‌شود، Database Export فایل موجود را overwrite نمی‌کند و Project Removal سورس پروژه را حذف نمی‌کند.

## ساختار مخزن

```text
Dockavel/
├── projects/
├── lib/
│   ├── database.sh
│   ├── help.sh
│   ├── project-commands.sh
│   ├── project-detection.sh
│   ├── project-health.sh
│   ├── project-manager.sh
│   └── shortcuts.sh
├── nginx/
├── tests/
├── CHANGELOG.md
├── VERSION
├── Dockerfile
├── Dockerfile-node
├── docker-compose.yml
├── dockavel
└── setup.sh
```

فایل‌های محلی مثل سورس پروژه‌ها، Nginx configهای تولیدشده، metadata پروژه‌ها و `.env` قرار نیست داخل مخزن Dockavel commit شوند.

## CI

GitHub Actions در حال حاضر این موارد را بررسی می‌کند:

- ترکیب‌های مختلف Compose Profile
- Build و Extensionهای موردنیاز PHP 8.2، 8.3، 8.4 و 8.5
- Build/runtime مربوط به Node.js 24
- Bash syntax ماژول‌های CLI و تست‌ها
- Smart Project Detection
- Project-aware command routing
- رفتار و safety مربوط به Database Helperها
- نصب/حذف Shortcut و symlink routing
- executable بودن CLI اصلی

## مستندات

مستندات کامل دو زبانه در این آدرس منتشر می‌شود:

https://afshinefati.github.io/dockavel-site/docs/

صفحه‌های مهم:

- [CLI و Shortcutها](https://afshinefati.github.io/dockavel-site/docs/commands/)
- [Workflowهای هوشمند](https://afshinefati.github.io/dockavel-site/docs/workflows/)
- [مدیریت پروژه](https://afshinefati.github.io/dockavel-site/docs/projects/)
- [Source و Diagnostics](https://afshinefati.github.io/dockavel-site/docs/network/)
- [Stack و Runtimeها](https://afshinefati.github.io/dockavel-site/docs/stack/)
- [رفع اشکال](https://afshinefati.github.io/dockavel-site/docs/troubleshooting/)
- [مرجع](https://afshinefati.github.io/dockavel-site/docs/reference/)

## Foundation تکمیل‌شده

```text
✅ Shared stack قابل تنظیم
✅ PHP 8.2 / 8.3 / 8.4 / 8.5
✅ MySQL / PostgreSQL / Redis / Node
✅ Regional download sources
✅ Project Manager
✅ Project-aware runtime commands
✅ Global CLI / Help / terminal shortcuts
✅ Smart Project Detection
✅ Project Health Check
✅ Database Helperها
✅ Doctor / Source Diagnostics
✅ Version / Changelog foundation
```

قابلیت‌های آینده باید شفاف و جداگانه اضافه شوند و نباید Core یا معماری Runtime/Source را بدون تصمیم صریح گسترش دهند.

## مشارکت

[CONTRIBUTING.md](CONTRIBUTING.md) را ببین.

هر Feature، Service، Runtime، Source preset، CLI command، Config، Port یا Workflow کاربرمحور باید `README.md`، `README.fa.md` و سایت/مستندات عمومی را همزمان به‌روز نگه دارد.

## License

MIT
