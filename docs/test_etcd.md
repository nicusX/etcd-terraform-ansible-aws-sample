# Verify *etcd* is working

The *etcd* cluster is now running and exposed through the ELB.
`<etc-elb-dns-name>` is the public DNS name of the ELB, outputs by Terraform.


Read *etcd* version:
```
$ curl -L http://<etc-elb-dns-name>:2379/version
{"etcdserver":"3.0.4","etcdcluster":"3.0.0"}
```

Set a key:
```
$ curl http://<etc-elb-dns-name>:2379/v2/keys/hello -XPUT -d value="world"
{"action":"set","node":{"key":"/hello","value":"world","modifiedIndex":8,"createdIndex":8}}
```

Retrieve a key:
```
$ curl http://<etc-elb-dns-name>:2379/v2/keys/hello
{"action":"set","node":{"key":"/hello","value":"world","modifiedIndex":8,"createdIndex":8}}
```
