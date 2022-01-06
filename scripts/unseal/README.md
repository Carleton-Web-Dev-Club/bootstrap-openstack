# Unseal

For when you have all your vault unseal keys and want to unseal the vault without copying them a bunch.

Provide a list of hosts via cli args, then provide the output from `vault operator init` to stdin. It will extract the keys and unseal all the vaults.

Obviously keeping all your unseal keys in one place is a terrible idea, but for development, this can speed it up a bit

