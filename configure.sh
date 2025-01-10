#!/bin/bash

echo "🚀 Configuring coder..."

if [ ! -d "/home/embold/.ssh" ]; then
    echo "🔧 Setting up SSH..."
    rsync -a --ignore-existing /coder/conf/.ssh /home/embold
    # Save GitHub's current keys from the API
    touch ~/.ssh/known_hosts
    curl -L https://api.github.com/meta | jq -r '.ssh_keys | .[]' | sed -e 's/^/github.com /' >>~/.ssh/known_hosts
    ssh-keyscan -t rsa embold.net >>/home/embold/.ssh/known_hosts

    mkdir -p /home/embold/.config/coder-api
    curl --request GET \
        --url "${CODER_AGENT_URL}api/v2/workspaceagents/me/gitsshkey" \
        --header "Coder-Session-Token: $CODER_AGENT_TOKEN" \
        -o /home/embold/.config/coder-api/gitsshkey.json &&
        jq -r '.public_key' /home/embold/.config/coder-api/gitsshkey.json |
        tr -d "\n" >/home/embold/.ssh/coder.pub &&
        echo -n " coder:$CODER_USERNAME@embold.dev" >>/home/embold/.ssh/coder.pub &&
        jq -r '.private_key' /home/embold/.config/coder-api/gitsshkey.json \
            >/home/embold/.ssh/coder

    sudo chmod 0700 /home/embold/.ssh
    sudo chmod 600 /home/embold/.ssh/*
    sudo chmod 600 /home/embold/.config/coder-api/gitsshkey.json

    # Configuring git to use the SSH key for signing
    git config --global gpg.format ssh
    git config --global commit.gpgsign true
    git config --global user.signingkey ~/.ssh/coder
fi

echo "⬇️ Pulling zshrc-base as /.zshrc-initial"
sudo mkdir /.zshrc-initial &&
    sudo chown embold:embold /.zshrc-initial &&
    git clone git@github.com:emboldagency/zshrc-base.git /.zshrc-initial

echo "➕ Installing Ruby gems..."
mkdir -p $GEM_HOME \
    && gem install colorls /coder/pulsar-*.gem --conservative

echo "🧐 Getting dotfiles URL..."
if [ -z $DOTFILES_URL]; then
    # Print a deprecation warning letting the user know that they should use the coder param
    echo "⚠️ DOTFILES_URL is not set. Fetching from the staging API is deprecated. Please fill in the dotfiles_url coder parameter instead."
    # Get dotfiles repo
    if [ ! -f /home/embold/.config/embold-api/dotfiles.json ]; then
        mkdir -p /home/embold/.config/embold-api
        curl -LGo /home/embold/.config/embold-api/dotfiles.json \
            "https://embold.net/api/dotfiles/" \
            -d user=$CODER_USERNAME
    fi

    DOTFILES_URL=$(jq -re '.repo' '/home/embold/.config/embold-api/dotfiles.json')
fi

if [ -n "$DOTFILES_URL" ]; then
    echo "Installing dotfiles from $DOTFILES_URL"
    coder dotfiles -y "$DOTFILES_URL"
fi

echo "➕ Installing lazygit..."
if ! command -v lazygit &>/dev/null; then
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit /usr/local/bin
    rm lazygit.tar.gz
fi

echo "➕ Installing browsersync..."
if [ ! -d "/home/embold/browsersync" ]; then
    git clone git@github.com:emboldagency/backend-browsersync.git /home/embold/browsersync
fi

echo "➕ Installing zoxide..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh)" "bash" --unattended >/dev/null 2>&1

echo "➕ Installing micro..."
curl https://getmic.ro | bash
sudo mv micro /usr/bin

# Who are we? ^_~
embold=H4sIAAAAAAAAA52SMQ7DMAhFd5+CqWPv0itkyFDJErbk+h+/wcTGtM7Q/iUKmCf4QLRWNW0XT5YKV4k660cggJtFdmAAifgPIJCBJ0Q5vwQPA6YBtH6TpUXJZYIAlHkiZ6BN/Piw4BM4qAGdpMzO8x5G61TLvzvs32DNdTDy5GF/bsuZ/j1QY6F11hZjzAXQVy2B6uIBlGCzjs6RCx3MeeJUnfWjWpMuw+IhZQWRjb27iuiXmegSeGz5PvZb5AQLUcl7G2XjGNmfIEde3V7lWLfzZXgDYVxqC3sDAAA=
base64 -d <<<"$embold" | gunzip
echo
echo "🎉 Workspace configured. Happy coding!"
