# GitOps based Install

This guide is not meant to be a definitive guide to [GitOps][gitops] and
how it can be used with UnderStack or even a best practices example
but instead focused on an example development oriented installation.
It will make a few assumptions and some opinionated choices that may
not align with a production best practices installation.
Most notable assumptions are:

- [GitOps][gitops] tooling runs on the same cluster as the deploy
- AIO (All-in-One) configuration
- Your cluster is a blank slate and can be entirely consumed

You will have the source to your deployment and all the pre-deployment
work will occur on your local machine and not on any of the target
machines.

## Getting the source

You must fetch the source to this repo and since we will be using
[GitOps][gitops], you must also have a deployment repo. These
operations can all happen locally on your development machine.

```bash
git clone https://github.com/rackerlabs/understack
# then either
git init uc-deploy
# or
git clone https://path/to/my/uc-deploy
```

## Pre-deployment

Embracing GitOps and declarative configuration, we will define three
distinct pieces of information for your deployment.

- Infrastructure: Where the software will live (TODO: this defines the cluster)
- Secrets: What are all the credentials, passwords, etc needed by the software
- Cluster: The actual software that will be deployed

To properly scope this you'll need an environment name. For the
purposes of this document we'll call it `my-k3s`.

### Environment Variables

To avoid defining many environment variables we'll simplify by creating an
`.env` file for our deployment. In this case we'll call it `my-k3s.env` and
place it where we've cloned understack. A complete file would like like

```bash title="/path/to/understack/my-k3s.env"
UC_REPO="$HOME/devel/understack"
UC_DEPLOY="$HOME/devel/uc-deploy"
DEPLOY_NAME="my-k3s"
UC_DEPLOY_GIT_URL=git@github.com:myorg/uc-deploy.git
UC_DEPLOY_SSH_FILE="$HOME/devel/uc-deploy-key"
DNS_ZONE=home.lab
UC_DEPLOY_EMAIL="my@email"
```

#### Paths

The `UC_REPO` and `UC_DEPLOY` variables are local paths on your machine to where
these two repos have been cloned.

#### Deployment Name

The `DEPLOY_NAME` variable contains the name that you'll refer to your
deployment as.

#### Git access for ArgoCD

ArgoCD will need to know where it can access your deployment config
repo. This can be over SSH with a key or over HTTPS or via a GitHub App.
At this time the scripts only support SSH. It is recommended to
use a [GitHub Deploy Key][gh-deploy-keys], the private key of which
should available locally and the path to it should be set into the
`UC_DEPLOY_SSH_FILE` variable. While the SSH clone URL for your repo
should be set to `UC_DEPLOY_GIT_URL`.

#### DNS for Ingress and SSL certificates

All services will utilize unique DNS names. The facilitate this, UnderStack
will take a domain and add sub-domains for them. The script will also create
a cluster issuer for [Cert Manager](https://cert-manager.io) which will use
the http01 solver by default, so you'll need to provide your email address
which needs to be set into the `UC_DEPLOY_EMAIL` variable.
All Ingress DNS names will be created as subdomains of the value you put
into the `DNS_ZONE` variable.

#### Getting Ready to Generate Secrets and Configs

You can run `source /path/to/understack/my-k3s.env` to have `$UC_DEPLOY` in
your shell.

### Populating the infrastructure

TODO: some examples and documentation on how to build out a cluster

### Generating secrets

Secrets in their very nature are sensitive pieces of data. The ultimate
storage and injection of these in a production environment needs to be
carefully considered. For the purposes of this document no specific
choice has been made but tools like Vault, Sealed Secrets, SOPS, etc
should be considered. This will only generate the necessary secrets
using random data to sucessfully continue the installation.

TODO: probably give at least one secure example

```bash
./scripts/gitops-secrets-gen.sh ./my-k3s.env
pushd "${UC_DEPLOY}"
git add secrets/my-k3s
git commit -m "my-k3s: secrets generation"
popd
```

### Defining the app deployment

In this section we will use the [App of Apps][app-of-apps] pattern to define
the deployment of all the components of UnderStack.

```bash
./scripts/gitops-deploy.sh ./my-k3s.env
pushd "${UC_DEPLOY}"
git add clusters/my-k3s
git commit -m "my-k3s: initial cluster config"
popd
```

## Final modifications of your deployment

This is point you can make changes to the [ArgoCD][argocd] configs before
you do the deployment in your `$UC_DEPLOY` repo. You'll want to consider
any changes to each of components to your cluster by modifying or adding
values files or kustomize patches. This should be considered a rough template
that is yours to modify. Once you've made all the changes you want to make,
ensure that you `git push` your `$UC_DEPLOY` repo so that ArgoCD can access it.

## Doing the Deployment

At this point we will use our configs to make the actual deployment.
Make sure everything you've committed to your deployment repo is pushed
to your git server so that ArgoCD can access it.

If you do not have ArgoCD deployed then you can use the following:

```bash
kubectl kustomize --enable-helm \
    https://github.com/rackerlabs/understack//bootstrap/argocd/ \
    | kubectl apply -f -
```

Now configure your ArgoCD to have the credential access to your deploy repo:

```bash
kubectl -n argocd apply -f "${UC_DEPLOY}/secrets/my-k3s/argocd/secret-deploy-repo.yaml"
```

Finally run the following to have ArgoCD deploy the system:

```bash
kubectl apply -f "${UC_DEPLOY}/clusters/my-k3s/app-of-apps.yaml"
```

At this point ArgoCD will work to deploy Understack.

[gitops]: <https://about.gitlab.com/topics/gitops/>
[app-of-apps]: <https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/>
[argocd]: <https://argo-cd.readthedocs.io/en/stable/>
[gh-deploy-keys]: <https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#set-up-deploy-keys>