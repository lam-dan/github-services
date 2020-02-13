
echo -n "Please enter release number (eg. 1.52.0)"
read release
export _Release=${release}
cd ..
for d in */; do
    echo "$d"
    cd "$d"
    git stash
    git fetch
    git checkout ${_Release}
    git branch
    git pull
    pwd
    cd ..
done
echo "Ending Script" 