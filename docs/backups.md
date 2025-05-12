# Backups

## Backup Index Database

```bash
cd /home/torrust/github/torrust/torrust-demo/
./share/bin/index-db-backup.sh 
```

## Check Backups Crontab Configuration

```bash
sudo crontab -e
```

You should see the [crontab.conf](../share/container/default/config/crontab.conf) configuration file.

## Check Backups

```bash
ls -alt /home/torrust/backups
total 26618268
-rwxr-x--- 1 root    root        2342912 May 12 07:00 backup_2025-05-12_07-00-01.db
-rwxr-x--- 1 root    root        2342912 May 12 06:00 backup_2025-05-12_06-00-02.db
-rwxr-x--- 1 root    root        2342912 May 12 05:00 backup_2025-05-12_05-00-01.db
-rwxr-x--- 1 root    root        2342912 May 12 04:00 backup_2025-05-12_04-00-01.db
```

YOu can also check the script output with:

```bash
tail /var/log/cron.log
```
