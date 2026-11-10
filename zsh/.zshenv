# Debian/Ubuntu's /etc/zsh/zshrc runs compinit before ~/.zshrc. That breaks
# zsh-autocomplete, which must run compinit itself. Must live in .zshenv
# (read before /etc/zsh/zshrc), not .zshrc.
skip_global_compinit=1
