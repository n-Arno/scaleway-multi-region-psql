Demo infrastructure
===================

Based on [this repository](https://github.com/n-Arno/scaleway-demo-mesh), check it for instructions.

The output can be used in the ansible `inventory`:

```
servers = [
  "par-1 ansible_user=root ansible_host=X.X.X.A lb_addr=Y.Y.Y.Y locality=region=fr-par,zone=fr-par-1",
  "par-2 ansible_user=root ansible_host=X.X.X.B lb_addr=Y.Y.Y.Y locality=region=fr-par,zone=fr-par-2",
  "ams-1 ansible_user=root ansible_host=X.X.Y.A lb_addr=Z.Z.Z.Z locality=region=nl-ams,zone=nl-ams-1",
  "ams-2 ansible_user=root ansible_host=X.X.Y.B lb_addr=Z.Z.Z.Z locality=region=nl-ams,zone=nl-ams-2",
]
```

Becomes:

```
[all]
par-1 ansible_user=root ansible_host=X.X.X.A lb_addr=Y.Y.Y.Y locality=region=fr-par,zone=fr-par-1
par-2 ansible_user=root ansible_host=X.X.X.B lb_addr=Y.Y.Y.Y locality=region=fr-par,zone=fr-par-2
ams-1 ansible_user=root ansible_host=X.X.Y.A lb_addr=Z.Z.Z.Z locality=region=nl-ams,zone=nl-ams-1
ams-2 ansible_user=root ansible_host=X.X.Y.B lb_addr=Z.Z.Z.Z locality=region=nl-ams,zone=nl-ams-2

[all:vars]
ansible_python_interpreter=auto_silent
ansible_remote_tmp=/tmp
ansible_shell_allow_world_readable_temp=true
webadmin_password=ChangeMe123!
```

Once the cockroachDB cluster is installed, you will be able to test connecting from both endpoint using the test servers and the LB IP:

```
test_servers = [
  "test-fr-par: ssh root@X.X.X.C",
  "test-nl-ams: ssh root@X.X.Y.C",
]
```

```
ssh root@X.X.X.C
psql 'postgresql://webadmin:ChangeMe123!@Y.Y.Y.Y:5432/'
```

```
psql (14.12 (Ubuntu 14.12-0ubuntu0.22.04.1), server 13.0.0)
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256, bits: 128, compression: off)
Type "help" for help.

webadmin=>
```
