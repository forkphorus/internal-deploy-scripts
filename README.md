# forkphorus deploy bot

The scripts that manage forkphorus.github.io

Prepare the repositories using HTTPS or SSH:

```bash
git clone git@github.com:forkphorus/forkphorus.github.io.git working/deploy
git clone git@github.com:forkphorus/forkphorus.git working/source
# or
git clone https://github.com/forkphorus/forkphorus.github.io.git working/deploy
git clone https://github.com/forkphorus/forkphorus.git working/source
```

Deploy:

```bash
./deploy.sh [branch]
```
