# Create the image with packer
```
packer init alpine-hcloud.pkr.hcl

packer build \
    -var alpine_branch=3.16 \
    packer/alpine-hcloud.pkr.hcl
```