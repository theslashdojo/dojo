# SSH Transfer Examples

## scp upload

```bash
scp build.tar.gz ops@host.example.com:/srv/releases/
```

## scp recursive upload

```bash
scp -r public/ ops@host.example.com:/srv/www/
```

## sftp batch file

```text
put -p build.tar.gz /srv/releases/build.tar.gz
get -p /var/log/api.log ./api.log
```

Run it with:

```bash
sftp -b deploy.sftp ops@host.example.com
```
