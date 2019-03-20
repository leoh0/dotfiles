
# dotfiles

*WIP*

* motivate from https://github.com/jessfraz/dotfiles

* setup base

```
sudo dotfiles/bin/install.sh base
# after reboot one more again
sudo dotfiles/bin/install.sh base
```

* setup dotfiles

```
dotfiles/bin/install.sh dotfiles
```

* setup background

```
DISPLAY=:0 nitrogen --save --set-zoom-fill --head=0,1 "/usr/share/backgrounds/al.jpg"
```

* setup gpg

```
gpg2 --full-gen-key
git config --global user.signingkey \
    $(gpg --list-keys | \
        grep ^pub | \
        cut -d'/' -f2- | \
        cut -d' ' -f1)
```

* setup git

```
# ignore .gitconfig
( cd $HOME/dotfiles; git update-index --skip-worktree .gitconfig)

GIT_AUTHOR_NAME="Eohyung Lee"
GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
GIT_AUTHOR_EMAIL="liquidnuker@gmail.com"
GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
GH_USER="leoh0"

git config --global user.name "$GIT_AUTHOR_NAME"
git config --global user.email "$GIT_AUTHOR_EMAIL"
git config --global github.user "$GH_USER"
git config --global user.signingkey \
    $(gpg --list-keys | \
        grep ^pub | \
        cut -d'/' -f2- | \
        cut -d' ' -f1)
```

* setup pass

```
PASS_ACCOUNT=liquidnuker@gmail.com
pass init "$PASS_ACCOUNT"
pass git init
```
