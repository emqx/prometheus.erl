# TLS Distribution Test Fixtures

These files are static TLS fixtures for `prometheus_vm_dist_collector_tests`.
They are used only to start local `inet_tls` Erlang distribution peers during
EUnit.

The certificate is self-signed and verification is disabled in the test startup
arguments. Do not use these files outside tests.

To regenerate the certificate and private key:

```sh
sh test/eunit/collectors/vm/tls_dist/regenerate.sh
```
