# Kodi + 群晖 MariaDB 共享媒体库

在群晖 NAS 上用容器运行 MariaDB，让多台 Kodi 设备共享同一个片库、观看状态和播放进度，并把缩略图缓存放到 NAS 上共享。

## 仓库内容

| 文件 | 用途 |
| --- | --- |
| `docker-compose.yml` | MariaDB 容器定义（Container Manager 项目 / docker compose） |
| `.env.example` | 环境变量模板，复制为 `.env` 后填写 |
| `sql/init-user.sql` | 创建 Kodi 专用数据库账号 |
| `advancedsettings.xml` | Kodi 客户端配置模板（数据库 + 缩略图共享） |
| `scripts/backup.sh` | 定时备份脚本（mariadb-dump + 保留 30 天） |

## 前提

- 群晖 DSM 7.2 及以上（套件中心已不再提供 MariaDB 10，所以用容器）
- 所有 Kodi 客户端**大版本一致**（数据库 schema 随版本变化，跨版本无法共用）
- 所有客户端访问媒体使用**完全相同的路径**（统一 `smb://` 或统一 `nfs://`）

## 1. 部署 MariaDB

```bash
cp .env.example .env
```

编辑 `.env`，把 `MARIADB_ROOT_PASSWORD` 改成强密码。

在 Container Manager 中新建项目，粘贴 `docker-compose.yml` 内容并构建；或在项目目录执行：

```bash
docker compose up -d
```

数据持久化在 `DATA_DIR`（默认 `/volume1/docker/kodi-mariadb`），容器重建不会丢库。

## 2. 创建 Kodi 数据库账号

```bash
docker exec -it kodi-mariadb mariadb -uroot -p
```

进入后执行 `sql/init-user.sql` 的内容。注意引号必须是英文半角 `'`，中文弯引号 `‘ ’` 会报 `ERROR 1064`。

Kodi 首次连接会自动创建 `MyVideos###` / `MyMusic###`，**不需要手动建库**。

## 3. 准备缩略图共享目录（可选）

1. 在群晖建共享文件夹（示例 `kodi-data`），在其下建子目录 `Thumbnails`。
2. 给所有 Kodi 客户端**读写**权限，否则封面缓存会静默失败。
3. NFS：控制面板 → 文件服务 → NFS 启用；共享文件夹 → 编辑 → NFS 权限，允许内网网段读写。写入报权限错误时将 Squash 设为「映射所有用户为 admin」。
4. SMB：给 Kodi 使用的账号共享权限，并在 `advancedsettings.xml` 中使用带凭据的 `smb://用户:密码@IP/共享名/Thumbnails/` 写法。

## 4. 配置 Kodi 客户端

1. 把 `advancedsettings.xml` 复制到每台设备的 userdata 目录，替换 `192.168.1.10` 和 `CHANGE_ME`：
   - Windows：`%APPDATA%\Kodi\userdata`
   - Android：`Android/data/org.xbmc.kodi/files/.kodi/userdata`
   - LibreELEC：`/storage/.kodi/userdata`
   - 其他平台：Kodi 设置 → 系统信息 查看 profile 路径
2. 完全退出 Kodi 再启动（返回主界面不算）。
3. **只在一台设备上扫描入库**，其他设备不要同时扫，避免重复条目。
4. 其他设备启动后即可看到相同片库和续播进度。

## 5. 验证

在任意一台电脑上远程登录数据库：

```bash
mysql -h <NAS_IP> -P 3306 -uxbmc -p
```

```sql
SHOW DATABASES;   -- 出现 MyVideos### / MyMusic### 即 Kodi 已写入
```

再在一台设备上播放到一半暂停，另一台设备应能看到续播点。

## 日常维护

- **备份**：把 `scripts/backup.sh` 放到群晖，改好密码，在任务计划中由 root 每天执行。数据库很小，备份成本很低。
- **恢复**：先退出所有 Kodi，再执行

```bash
gunzip -c /volume1/backup/kodi/kodi-YYYYMMDD-HHMM.sql.gz | docker exec -i kodi-mariadb mariadb -uroot -p
```

- **片库维护**：扫描、清理资料库、导出 NFO 都在 Kodi 界面里做，**不要直接用 SQL 改表**。
- **升级 Kodi 大版本**：会新建 `MyVideos###`，旧库保留；确认新版正常后再删旧库释放空间。
- **升级 MariaDB 镜像**：先备份，再更新镜像并重建容器。
- **安全**：3306 只开给局域网，绝不做公网端口映射；`xbmc` 密码不要用弱口令。

## 常见问题

| 现象 | 处理 |
| --- | --- |
| Kodi 连不上数据库 | 检查 `host` 是否为 IP、群晖防火墙是否放行 3306、容器端口映射 |
| `ERROR 1064` | SQL 里用了中文引号，改成英文半角 |
| 多台设备条目重复 | 不要在多个客户端同时扫描；用「清理资料库」后单台重扫 |
| 缩略图不显示 | Thumbnails 目录不存在或客户端无写权限；检查 NFS/SMB 权限 |
| 升级 Kodi 后不同步 | 各客户端大版本不一致，统一版本 |
| Apple TV 装不了 Kodi | A12/A15 机型（如 A2843）无公开越狱，tvOS `.deb` 无法安装；改用 Infuse / Jellyfin / Plex 客户端 |

## 参考

- [Kodi Wiki: MySQL](https://kodi.wiki/view/MySQL)
- [Kodi Wiki: advancedsettings.xml](https://kodi.wiki/view/Advancedsettings.xml)
- [Kodi Wiki: Path substitution](https://kodi.wiki/view/Path_substitution)
