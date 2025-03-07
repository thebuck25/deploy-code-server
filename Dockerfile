# Start from the code-server Debian base image
FROM codercom/code-server:4.96.4

USER coder

# Apply VS Code settings
COPY deploy-container/settings.json .local/share/code-server/User/settings.json

# Use bash shell
ENV SHELL=/bin/bash

# Install unzip + rclone (support for remote filesystem)
RUN sudo apt-get update && sudo apt-get install unzip -y
RUN curl https://rclone.org/install.sh | sudo bash

# Copy rclone tasks to /tmp, to potentially be used
COPY deploy-container/rclone-tasks.json /tmp/rclone-tasks.json

# Fix permissions for code-server
RUN sudo chown -R coder:coder /home/coder/.local

# Install AzCLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Terraform
RUN sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
RUN sudo apt update
RUN sudo apt-get install terraform

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN sudo ./aws/install

# Install VS Code extensions:
# Note: we use a different marketplace than VS Code. See https://github.com/cdr/code-server/blob/main/docs/FAQ.md#differences-compared-to-vs-code
# First copy any manually installed extensions to docker

#Registry install
RUN code-server --install-extension esbenp.prettier-vscode
RUN code-server --install-extension ms-vscode.vscode-typescript-next
RUN code-server --install-extension ms-vscode.azure-account
RUN code-server --install-extension ms-azuretools.vscode-azurefunctions
RUN code-server --install-extension HashiCorp.terraform
RUN code-server --install-extension GitHub.vscode-github-actions
RUN code-server --install-extension github.github-vscode-theme
RUN code-server --install-extension GitHub.vscode-pull-request-github
RUN code-server --install-extension AmazonWebServices.amazon-q-vscode
RUN code-server --install-extension AmazonWebServices.aws-toolkit-vscode

#Manual install
ENV EXTENSIONS_DIR=.local/share/code-server/extensions
RUN mkdir -p ${EXTENSIONS_DIR}
# Copy all .vsix files from the "extensions" folder on your local machine to the Docker image
COPY ./extensions/*.vsix ${EXTENSIONS_DIR}/
RUN for ext in ${EXTENSIONS_DIR}/*.vsix; do \
    code-server --install-extension $ext; \
done

# Install apt packages:
RUN sudo apt-get update --fix-missing
RUN sudo apt-get install -y make
RUN sudo apt-get install -y curl
RUN sudo apt-get install -y build-essential libssl-dev
RUN sudo apt-get install -y wget unzip fontconfig
RUN sudo apt-get install -y inotify-tools

# Setup NVM:
# Create a script file sourced by both interactive and non-interactive bash shells
ENV BASH_ENV /home/coder/.bash_env
# Setup NVM:
RUN sudo mkdir -p /usr/local/nvm
ENV NVM_DIR /usr/local/nvm
RUN chown -R coder:coder /usr/local/nvm
ENV NODE_VERSION --lts
RUN touch "${BASH_ENV}"
RUN echo '. "${BASH_ENV}"' >> ~/.bashrc
RUN cat ~/.bashrc

# Download and install nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | PROFILE="/home/coder/.bash_env" bash
RUN echo node > .nvmrc
RUN nvm install

# Setup shell w/ powerline10k theme, no zsh plugins installed
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.2.0/zsh-in-docker.sh)"
# Change the default shell for "coder" to zsh
RUN ZSH_PATH=$(which zsh) && sudo sed -i "s|/bin/bash|${ZSH_PATH}|" /etc/passwd

# Copy ZSH files: 
COPY --chown=coder:coder .zshrc /home/coder/.zshrc
COPY --chown=coder:coder .p10k.zsh /home/coder/.p10k.zsh

# Setup NVM:
#ENV NVM_DIR /usr/local/nvm
#ENV NODE_VERSION --lts
#RUN sudo mkdir -p /usr/local/nvm
#RUN sudo chown -R coder:coder /usr/local/nvm
#RUN wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
#ENV NODE_PATH $NVM_DIR/versions/node/$NODE_VERSION/bin
#ENV PATH $NODE_PATH:$PATH

# Fetch the latest Geist font release
RUN LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/vercel/geist-font/releases/latest | grep "browser_download_url" | grep ".zip" | cut -d '"' -f 4 | grep Mono) \
    && wget -O geist-font.zip $LATEST_RELEASE_URL

# Unzip the downloaded file
RUN unzip geist-font.zip -d geist-font
RUN ls geist-font
RUN pwd

# Install the fonts to the system fonts directory
RUN sudo mkdir -p /usr/share/fonts/truetype/geist-font
RUN sudo find geist-font/ -type f -name '*.ttf' -exec cp '{}' /usr/share/fonts/truetype/geist-font/ ';'

# Install Meslo fonts for p10k
RUN wget -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
RUN wget -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
RUN wget -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
RUN wget -O https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf

# Install the fonts to the system fonts directory
RUN sudo mkdir -p /usr/share/fonts/truetype/meslolgs
RUN sudo find ./ -type f -name '*.ttf' -exec cp '{}' /usr/share/fonts/truetype/meslolgs/ ';'

# Update the font cache
RUN sudo fc-cache -fv

# Cleanup unnecessary files
RUN sudo rm -rf geist-font.zip geist-font
RUN sudo rm *.ttf

# Set env vars before boot
ENV PORT=8080

# Use our custom entrypoint script first
COPY deploy-container/entrypoint.sh /usr/bin/deploy-container-entrypoint.sh
ENTRYPOINT ["/usr/bin/deploy-container-entrypoint.sh"]
