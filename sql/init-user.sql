-- Kodi 专用数据库账号，所有客户端共用。
-- 注意：SQL 引号必须是英文半角 '，中文弯引号 ‘ ’ 会导致 ERROR 1064。
-- 密码请改成强密码，并同步修改各客户端 advancedsettings.xml。

CREATE USER 'xbmc'@'%' IDENTIFIED BY 'CHANGE_ME';
GRANT ALL PRIVILEGES ON *.* TO 'xbmc'@'%';
FLUSH PRIVILEGES;

-- 验证
SELECT User, Host FROM mysql.user WHERE User = 'xbmc';
SHOW GRANTS FOR 'xbmc'@'%';
