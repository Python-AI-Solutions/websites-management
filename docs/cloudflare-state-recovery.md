# Cloudflare state recovery

This OpenTofu root manages only the Cloudflare resources declared by
`root/`, its Cloudflare modules, and `envs/prod.tfvars`. The AWS and Kubernetes
roots in this repository have separate state and are outside this procedure.

## Current authority status

The production Cloudflare objects have been imported from the live API into a
fresh local `prod` workspace. The imported records were reconciled and a final
plan found no changes across the 45 managed resource instances. This local
`prod` state is the production authority.

Use this worktree as the only production OpenTofu operator. Do not create a
second production state or import the same objects elsewhere. Local state has
no distributed lock, so never run overlapping plan or apply processes.

## Reconciliation checks

Load the Cloudflare credentials, initialize the root, and verify the workspace:

```bash
source scripts/load-env.sh
tofu -chdir=root init
tofu -chdir=root workspace select prod
test "$(tofu -chdir=root workspace show)" = prod
```

Review live drift without changing Cloudflare:

```bash
tofu -chdir=root plan \
  -refresh-only \
  -var-file=../envs/prod.tfvars
```

Then review the configuration plan:

```bash
pixi run plan-prod
```

An import can normalize computed provider fields differently from an older
state. Treat every proposed DNS update as material even when there are no
creates or deletes. Inspect the complete plan before approving it.

## Protect the local authority

Before and after every production apply, back up the state into an encrypted
location outside the repository:

```bash
umask 077
tofu -chdir=root state pull > /path/to/encrypted-backup/terraform-prod.tfstate
```

State files can contain infrastructure identifiers and record values. Never
commit a state file or place an unencrypted backup in the repository.
