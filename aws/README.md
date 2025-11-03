# AWS infrastructure

This configuration captures the existing jump host EC2 instance (`i-08da10999e8ebcefa`) together with its elastic IP. The configuration is written for [OpenTofu](https://opentofu.org) and assumes credentials are already available via the default AWS CLI configuration.

## Getting started

```bash
cd aws
tofu init
```

## Import the existing resources

Before running any plan or apply you must import the currently running resources so that OpenTofu links them to the configuration instead of trying to recreate them.

```bash
# Import the security group
tofu import aws_security_group.jump_host sg-0941550cf497338b7

# Import the EC2 instance
tofu import aws_instance.jump_host i-08da10999e8ebcefa

# Import the elastic IP allocation
tofu import aws_eip.jump_host eipalloc-050f076c6d971ed4b
```

Once both imports succeed, verify that the state matches the live infrastructure:

```bash
tofu plan
```

The plan should report **no changes**. The `prevent_destroy` lifecycle flag on both resources ensures the instance and elastic IP cannot be destroyed accidentally. Update variables in `variables.tf` if you need to reflect changes to the underlying resources over time.

The security group is now fully managed (including the new TCP 7005 rule). Adjust the allowed CIDRs through `var.jump_host_ssh_cidrs` and `var.jump_host_port_7005_cidrs` if you need to restrict access.

### Notes

- The configuration pins values (AMI, subnet, volume settings, etc.) to the current live state so that subsequent changes are explicit. Adjust these variables if you intentionally modify the instance outside of OpenTofu.
