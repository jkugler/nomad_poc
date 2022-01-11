You will need to build an image you can use.

```
packer build packer.json
```

Once done building, put the AMI id in terraform.tfvars

Run `terraform apply`

When it errors out, run `terraform output`

Take the server IPs and invoke the cluster initialization:
```
./init_cluster.sh IP1 IP2 IP3
```
Then run `terraform apply` again.
