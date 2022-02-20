# Конфигурация компьютеров в НТТЭК
В данном репозитории хранятся все конфигурационные файлы, которые необходимы для полноценной работы компьютеров. Ниже представленны описания работы каждых конфигурационных файлов.

### Ubuntu Desktop/postinstall.sh
Данный файл необходим для запуска после установки Ubuntu Desktop на компьютеры в колледже. Пример запуска файла:
```console
root@ubuntu:~$ bash postinstall.sh \
--ip-address 192.168.0.10 \
--ip-mask 24 \
--ip-gateway 192.168.0.1 \
--ip-dns 8.8.8.8 \
--ldap-cert /path/to/ldap/certificate.pem \
--ldap-key /path/to/ldap/private.key \
--domain example.com \
--ldap-base dc=example,dc=com
```
После запуска данного скрипта, Ubuntu Desktop сконфигурируется на авторизацию с использованием Google LDAP, и получения статичного IP-адреса, а также в систему будет установлен OpenSSH Server.
