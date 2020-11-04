# [favor-group.ru](https://favor-group.ru) infrastructure as a code

This repository contains infrastructure code behind [favor-group.ru](https://favor-group.ru), a site
of my father's metal decking business operating in Moscow and a few other Russia's cities.

## /private structure

`private/environment/percona.env` should contain `MYSQL_ROOT_PASSWORD`, `MYSQL_USER` and `MYSQL_PASSWORD`.

`pmm/pmm-agent.yaml` should contain agent setup which is done according to
[this doc](https://gist.github.com/paskal/48f10a0a584f4849be6b0889ede9262b).
Server counterpart sets up by the same doc and is running [there](https://github.com/paskal/terrty/).

## Certificate renewal

At this moment DNS verification of wildcard certificate is not yet set up.
To renew the certificate, run the following command and follow the interactive prompt:

```shell
docker-compose run --rm --entrypoint "\
  certbot certonly \
    --email msk@favor-group.ru \
    -d favor-group.ru -d *.favor-group.ru \
    --agree-tos \
    --manual \
    --preferred-challenges dns" certbot
```

In order to add required TXT entries, head to [DNS edit page](https://fornex.com/my/dns/favor-group.ru/).
