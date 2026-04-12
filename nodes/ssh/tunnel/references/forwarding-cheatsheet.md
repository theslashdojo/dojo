# SSH Forwarding Cheatsheet

## Local forward

```bash
ssh -L 5433:127.0.0.1:5432 ops@db-gateway.example.com -N
```

## Remote forward

```bash
ssh -R 8080:127.0.0.1:3000 ops@bastion.example.com -N
```

## Dynamic forward

```bash
ssh -D 1080 ops@bastion.example.com -N
```

## Safe backgrounding

```bash
ssh -f -n -o ExitOnForwardFailure=yes -L 5433:127.0.0.1:5432 ops@db-gateway.example.com -N
```
