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
  local commit=$(git log --pretty=format:'%s' -n 1)
  if [[ $commit =~ Deploy\ ([a-f0-9]{40}) ]]; then
    echo ${BASH_REMATCH[1]}
  else
    echo "Cannot find commit"
    exit 1
  fi
}

get_current_commit() {
  cd $source
  echo $(git rev-parse HEAD)
}

yes_or_no() {
  echo
  # https://stackoverflow.com/a/29436423
  while true; do
    read -p "[Deploy] $* [y/n]: " yn
    case $yn in
      [Yy]*) return 0 ;;  
      [Nn]*) echo "Aborted" ; return 1 ;;
    esac
  done
}

oldCommit=$(get_old_commit)
newCommit=$(get_current_commit)

echo "[Deploy] Updating repositories"

cd $deploy
git reset --hard
git checkout master
git pull origin master

cd $source
git reset --hard
git checkout $branch
git pull origin $branch -Xtheirs

merge_trees $source $deploy
merge_trees $dir/patches $deploy
apply_index_mods

echo "[Deploy] Installing & Building"
cd $deploy
npm ci
npm run build

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
echo

if ! yes_or_no "Continue with commit?"; then
  exit 1
fi

git commit -m "[$branch] Deploy $newCommit" -m "https://github.com/forkphorus/forkphorus/compare/$oldCommit...$newCommit"

if yes_or_no "Complete deploy?"; then
  git push origin master
else
  git reset --hard HEAD~1
  exit 1
fi

echo
echo ":D"
echo
