#!/bin/bash

set -e
set -o pipefail

dir="$( cd "$(dirname "$0")" ; pwd -P )"
cd $dir

if [ "$1" != "" ]; then
  branch=$1
else
  branch=master
fi

if [ ! -d "working" ]; then
  ./init.sh
fi

deploy=$dir/working/deploy
if [ "$branch" != "master" ]; then
  deploy=$deploy/$branch
  mkdir -p $deploy
fi

source=$dir/working/source

merge_trees() {
  local source=$1
  local dest=$2
  cd $source
  find . -type f | grep -v .git | xargs -I % cp % --parents $dest
}

apply_index_mods() {
  local index="$deploy/index.html"
  local content=`cat $index`

  cd $source
  local versionText="Version $(git rev-parse --verify HEAD --short), updated $(date +%Y-%m-%d)"
  if [ "$branch" != "master" ]; then
    local versionText="$versionText [on branch $branch]"
    local html="<p><b>This is an experimental version of forkphorus. It may stop working at any time.</b></p>"
    local content="${content/<div id=\"app\">/<div id=\"app\">$html}"
  fi
  local versionText="<p style=\"opacity:0.5;\"><small>$versionText</small></p>"
  cd $deploy
  local content="${content/<!-- __deploybotinfosection__ -->/$versionText}"

  local google="<meta name="google-site-verification" content=\"fxogd82_Q_zvblLPSbkmRDktBJG5MK8mH8Xeg8ONDEc\" />"
  local content="${content/<\/title>/<\/title>$google}"

  echo "$content" > $index
}

get_old_commit() {
  cd $deploy
  local commits=$(git log --pretty=format:'%s' -n 20 | grep '[$1]')
  if [[ $commits =~ [a-f0-9]{40} ]]; then
    echo $BASH_REMATCH
  else
    echo "???"
  fi
}

get_current_commit() {
  cd $source
  echo $(git rev-parse HEAD)
}

yes_or_no() {
  # https://stackoverflow.com/a/29436423
  while true; do
    read -p "[Deploy] $* [y/n]: " yn
    case $yn in
      [Yy]*) return 0 ;;  
      [Nn]*) echo "Aborted" ; return 1 ;;
    esac
  done
}

scan_script() {
  local script=$1
  #if [[ $(cat $script) =~ ' debugger;' ]]; then
  #  echo "Found bad debugger statement in $script; aborting"
  #  exit 1
  #fi
}

echo "[Deploy] Updating repositories"

cd $deploy
git fetch
git reset --hard origin/master

cd $source
git reset --hard
git checkout $branch
git pull origin $branch -Xtheirs

oldCommit=$(get_old_commit $branch)
newCommit=$(get_current_commit)

if [[ $oldCommit == $newCommit ]]; then
  if ! yes_or_no "New commit and old commit appear to be the same. Continue? ($newCommit)"; then
    exit 1
  fi
fi

merge_trees $source $deploy
merge_trees $dir/patches $deploy
apply_index_mods

echo "[Deploy] Installing & Building"
cd $deploy
npm ci
npm run build

scan_script phosphorus.dist.js

echo "[Deploy] Running tests"
cd tests
if [ ! -d node_modules ]; then
  npm ci
fi
node runner.js

cd $deploy
rm -r phosphorus tsconfig.json package.json package-lock.json dev.js
if [ "$branch" != "master" ]; then
  rm README.md LICENSE
fi
git stage .

echo "[Deploy] Modified files:"
git status -s
echo "(paths relative to $deploy)"
echo

subject="[$branch] Deploy $newCommit"
echo "[Deploy] Subject: $subject"

if ! yes_or_no "Continue with commit?"; then
  exit 1
fi

git commit -m "$subject" -m "https://github.com/forkphorus/forkphorus/compare/$oldCommit...$newCommit"

if yes_or_no "Push?"; then
  git push origin master
else
  git reset --hard HEAD~1
  exit 1
fi

echo
echo "Everything is good!"
echo
