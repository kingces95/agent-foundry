# Configure a Computer as a Codex Remote SSH Target

Configure this computer so an approved client computer can connect over SSH
using a public key and launch Codex Remote from a working login shell.

Perform the setup safely, preserve existing access, and verify the completed
connection from the client.

## Desired outcome

- Use the operating system's native SSH service and native Codex installation.
- On Windows, use Git for Windows Bash as the SSH login shell.
- Do not install or configure WSL merely for Codex Remote.
- Do not reboot the computer. If an installation unexpectedly requires a
  reboot, stop and report that requirement instead of rebooting.
- A brief restart of the SSH service is acceptable after its configuration has
  been validated and existing SSH sessions have been preserved.

## Safety rules

- Never request, display, copy, or transmit a private key.
- Never overwrite an existing `authorized_keys` or `known_hosts` file.
- Do not disable password authentication until public-key login has been tested
  successfully from the client.
- Do not alter unrelated SSH settings.
- Before installing software, changing firewall exposure, or changing the
  machine-wide Windows OpenSSH login shell, describe the action and request
  approval.
- Detect the operating system and adapt the commands accordingly.
- Prefer Ed25519 keys.
- Back up every configuration file and relevant registry key before modifying
  it.
- Validate SSH configuration before restarting `sshd`.
- If validation or the fresh-connection test fails, restore the backup.
- Do not expose SSH beyond the existing trusted network unless explicitly
  authorized.
- Keep at least one existing administrator session open until a fresh SSH
  connection has passed every verification step.

## Inspect first

Inspect and report:

1. Operating system and version.
2. Computer hostname, DNS name, and relevant IP addresses.
3. Whether OpenSSH Server is installed and running.
4. Existing SSH listening addresses and firewall scope.
5. Current SSH login shell.
6. Whether Git Bash or another POSIX-compatible login shell is installed.
7. Whether `codex` is installed and discoverable through `PATH` from a
   non-interactive SSH login:

   ```sh
   command -v codex && codex --version
   ```

8. Existing SSH host-key types and SHA256 fingerprints. Never display private
   host keys.
9. Whether the selected login user is an administrator.
10. On Windows, the existing values, if any, of:

    ```text
    HKLM\SOFTWARE\OpenSSH\DefaultShell
    HKLM\SOFTWARE\OpenSSH\DefaultShellCommandOption
    ```

## Request the connection details

Ask me for:

- The login account that should accept Codex Remote connections.
- The client's complete public-key line, for example:

  ```text
  ssh-ed25519 AAAA... label
  ```

- Optional source restrictions for the key, such as a client IP or subnet.
- Whether password login should remain enabled after key authentication has
  been verified.

## Validate the client public key

- It must be exactly one public-key record.
- Accept modern key types such as `ssh-ed25519`.
- Reject private-key headers, multiline material, shell commands, malformed
  base64, and unexpected options.
- Show its SHA256 fingerprint and ask for confirmation before installing it.

## Configure incoming authentication

### Windows

1. Install and enable the Microsoft OpenSSH Server capability if necessary.
2. Ensure the `sshd` service starts automatically.
3. Back up `C:\ProgramData\ssh\sshd_config` before editing it.
4. If the selected user is covered by this block:

   ```text
   Match Group administrators
       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
   ```

   install the key in:

   ```text
   C:\ProgramData\ssh\administrators_authorized_keys
   ```

   Otherwise, install it in the selected user's:

   ```text
   %USERPROFILE%\.ssh\authorized_keys
   ```

5. Apply the restrictive ACLs required by Windows OpenSSH.
6. Append the new key without removing existing keys.
7. Validate the configuration with the installed `sshd.exe -t` before
   restarting the service.

### Linux or macOS

1. Install the client public key in the selected account's
   `~/.ssh/authorized_keys`.
2. Set the directory to mode `700` and the file to mode `600` while preserving
   ownership.
3. Confirm the account's configured shell is executable and supports login and
   non-interactive commands.
4. Confirm this works for the selected account:

   ```sh
   ssh localhost 'command -v codex && codex --version'
   ```

5. Validate `sshd_config` with `sshd -t` before reloading or restarting SSH.

## Configure the Windows shell for Codex Remote

Codex Remote starts the remote Codex app server through the SSH user's login
shell. A default Windows `cmd.exe` shell is insufficient because the bootstrap
uses POSIX commands such as `sh` and `[`. Use Git for Windows Bash without WSL.

1. Confirm this executable exists and works:

   ```text
   C:\Program Files\Git\bin\bash.exe
   ```

2. Explain that the Windows OpenSSH `DefaultShell` setting is machine-wide and
   affects every user of this SSH server. Request approval before changing it.
3. Export a backup of `HKLM\SOFTWARE\OpenSSH`, including any existing
   `DefaultShell` values.
4. Configure:

   ```text
   HKLM\SOFTWARE\OpenSSH\DefaultShell
   C:\Program Files\Git\bin\bash.exe
   ```

5. Configure:

   ```text
   HKLM\SOFTWARE\OpenSSH\DefaultShellCommandOption
   -c
   ```

6. Confirm Bash can find Codex in a clean login environment:

   ```sh
   bash -l -c 'command -v codex && codex --version'
   ```

7. If Codex is missing, stop and request approval for a specific native Windows
   installation method. Do not invent or silently download an installer.
8. Validate `sshd_config` using `sshd.exe -t`. This validates the SSH
   configuration file but **does not validate the registry shell settings**.
9. Restart only the `sshd` service. Do not reboot Windows.
10. From a fresh client SSH connection, verify the registry-backed shell and
    the POSIX commands that previously failed:

    ```sh
    ssh USER@HOST 'printf "SSH_OK\n"; command -v sh; command -v codex; codex --version; [ -n "$HOME" ] && printf "POSIX_OK\n"; printf "SHELL=%s\n" "$SHELL"'
    ```

11. If the fresh test fails, keep the original administrator session open,
    restore the registry backup, restart `sshd`, and report the failure.

## Configure network access

- Confirm SSH is listening on the expected interface and port.
- If a firewall rule is needed, restrict it to the client IP or trusted LAN
  subnet when practical.
- Report the resulting hostname, IP, port, and username.

## Offer the server's host identity to the client

Read only the server's **public** host keys. Prefer the Ed25519 host key.

Display:

- Key type.
- SHA256 fingerprint.
- Hostname.
- FQDN, if available.
- Relevant IP addresses.
- Ready-to-install `known_hosts` records for every approved hostname and IP.
  Use `[host]:port` form when SSH uses a non-default port.

Never display or copy a private host key. Explain that the user should verify
the fingerprint through this trusted setup session before accepting it.

## Prepare the client

Provide client-side installation commands without executing them unless the
client is also explicitly in scope.

For an OpenSSH client, provide commands that:

1. Create the SSH directory if necessary.
2. Back up the existing `known_hosts` file.
3. Append the verified `known_hosts` record without replacing existing entries.
4. Add a concrete host alias to `~/.ssh/config`, including `HostName`, `User`,
   `IdentityFile`, and `Port` when non-default.
5. Test strict host-key verification:

   ```sh
   ssh -o StrictHostKeyChecking=yes USER@HOST \
     'printf "SSH_OK\n"; command -v sh; command -v codex; codex --version; [ -n "$HOME" ] && printf "POSIX_OK\n"; printf "SHELL=%s\n" "$SHELL"'
   ```

Do not recommend `StrictHostKeyChecking=no`.

## Verification ceremony

1. Install the client public key on the server.
2. Give me the server host-key fingerprint and `known_hosts` record.
3. Pause while I install that host key on the client.
4. Ask me to run the strict test command from the client.
5. Do not disable password authentication yet.
6. After I confirm key-only login works, optionally configure
   `PubkeyAuthentication yes` and, only with explicit confirmation,
   `PasswordAuthentication no`.
7. Validate the configuration again and restart or reload SSH.
8. Ask me to perform one final connection before declaring success.
9. Have me enable the host in the Codex desktop app and confirm that Codex
   Remote starts successfully, not merely that ordinary SSH succeeds.

## Final report

Report:

- Server hostname, FQDN, IP, and SSH port.
- Login account.
- Installed client-key fingerprint.
- Server host-key fingerprint.
- Location of `authorized_keys`.
- Configured login shell.
- Previous login shell and how to restore it.
- `codex` executable path and version.
- SSH service status and startup mode.
- Firewall scope.
- Whether password authentication remains enabled.
- Exact strict client test command.
- Backups created, registry values changed, and configuration files changed.
- Confirmation that no WSL was configured and Windows was not rebooted.
