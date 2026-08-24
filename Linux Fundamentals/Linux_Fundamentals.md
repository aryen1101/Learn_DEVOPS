# Linux Fundamentals

This document contains commonly used Linux commands and basic concepts. Most commands are case-sensitive.

## 1. Updating Ubuntu/Debian packages

```bash
sudo apt update
```

Downloads the latest package lists from the configured repositories. It does not install updates.

```bash
sudo apt upgrade
```

Installs available updates for already-installed packages. It may update the kernel and other system packages, but it does not automatically update every driver or boot file.

Useful related commands:

```bash
apt list --upgradable       # Show available updates
sudo apt full-upgrade       # Upgrade packages and handle dependency changes
sudo apt install package    # Install a package
sudo apt remove package     # Remove a package
```

## 2. Username, hostname, and the shell prompt

- **Username:** identifies the user currently logged in.
- **Hostname:** identifies the computer or system.

Example prompt:

```text
aryen@Aryen-Laptop:~$
```

- `aryen` — username
- `@` — separates the username and hostname
- `Aryen-Laptop` — hostname
- `~` — the current user's home directory
- `$` — a regular user prompt (`#` usually indicates the root user)

### Find the hostname

```bash
hostname
hostnamectl
hostname -s     # Short hostname
hostname -f     # Fully qualified hostname, if configured
hostname -i     # IP address(es) associated with the hostname
```

### Find information about users

```bash
whoami          # Effective/current username
id              # User ID, group ID, and group memberships
who             # Users currently logged in
w               # Logged-in users and what they are doing
logname         # Login name, when available
echo "$USER"    # Username from the USER environment variable
users           # Names of logged-in users
```

## 3. Operating-system information

```bash
cat /etc/os-release
hostnamectl
uname -a        # Kernel and system information
```

`/etc/os-release` is the standard source for Linux distribution information. `/etc/*release` is a shell glob that may match multiple files; it is not a reliable way to report every operating system installed on the machine.

## 4. Files and directories

### Create files

```bash
touch file.txt              # Create an empty file, or update its timestamp
touch file1 file2 file3     # Create multiple files
nano file.txt               # Create/edit with Nano
vim file.txt                # Create/edit with Vim
echo "content" > file.txt  # Write content, replacing existing content
```

`>` overwrites a file. Use `>>` to append instead:

```bash
echo "more content" >> file.txt
```

### Read files

```bash
cat file.txt                # Display the complete file
less file.txt               # View page by page; press q to quit
more file.txt               # Basic page-by-page viewer
head file.txt               # First 10 lines
tail file.txt               # Last 10 lines
tail -f logfile.log         # Follow new lines added to a log
```

### Create and navigate directories

```bash
mkdir directory             # Create one directory
mkdir dir1 dir2             # Create multiple directories
mkdir -p dir1/dir2          # Create parent directories as needed
cd directory                # Change directory
cd ..                       # Move to the parent directory
cd ~                        # Move to the current user's home directory
cd -                        # Return to the previous directory
pwd                         # Print the current path
```

### List directory contents

```bash
ls                          # List the current directory
ls directory                # List a specific directory
ls -a                       # Include hidden entries
ls -l                       # Long, detailed format
ls -la                      # Detailed format including hidden entries
```

Files and directories whose names begin with `.` are hidden by default. For example, `touch .env` creates a hidden file.

### Copy, move, rename, and remove

```bash
cp source destination        # Copy a file
cp -r source_dir destination # Copy a directory recursively
mv source destination        # Move a file or directory
mv old_name new_name         # Rename a file or directory
rm file.txt                  # Remove a file
rmdir empty_directory        # Remove an empty directory
rm -r directory               # Remove a directory and its contents
```

Be careful with `rm -r`; removed files normally do not go to a recycle bin. Use `rm -i` when you want confirmation before removal.

```bash
clear                        # Clear the terminal display
history                      # Show previously executed commands
```

## 5. Processes and system monitoring

```bash
ps                           # Processes associated with the current shell
ps -ef                       # Detailed list of all running processes
ps aux                       # BSD-style detailed list of all processes
top                          # Real-time process and resource monitor
htop                         # Interactive alternative to top, if installed
```

`ps -a` shows processes associated with terminals, excluding session leaders; it does not show all services and processes. Use `ps -ef` or `ps aux` for a broad process list.

Each process has a process ID (PID). To stop a process:

```bash
kill PID                     # Request graceful termination
kill -9 PID                  # Force termination; use only when necessary
pkill process_name           # Terminate processes matching a name
```

## 6. File permissions: `chmod`

`chmod` means “change mode” and changes file or directory permissions.

| Permission | Symbol | File meaning | Directory meaning |
| --- | --- | --- | --- |
| Read | `r` | Read contents | List entries |
| Write | `w` | Modify contents | Create, delete, or rename entries |
| Execute | `x` | Run as a program | Enter/traverse the directory |

Permissions are set for `u` (user/owner), `g` (group), `o` (others), or `a` (all).

```bash
chmod +x script.sh            # Add execute permission for all categories
chmod u+rwx file.txt          # Give the owner read, write, and execute
chmod go-w file.txt           # Remove write permission from group and others
```

Numeric permissions use `r = 4`, `w = 2`, and `x = 1`:

```bash
chmod 755 script.sh
```

`755` means owner `7` = `rwx`, group `5` = `r-x`, and others `5` = `r-x`. The resulting permission string is `-rwxr-xr-x` for a regular file. The first character indicates the file type; `-` means regular file and `d` means directory.

The temporary directory `/tmp` commonly has mode `1777`, not simply `777`. The leading `1` is the sticky bit, which prevents users from deleting or renaming other users' files there:

```bash
ls -ld /tmp
```

## 7. Forward slash and backslash

Linux uses `/` to separate directories in paths, such as `/home/aryen/Documents`. `/` by itself is the root directory.

In most Linux shells, `\` escapes the next character. It can include a space in an unquoted argument:

```bash
echo Hello\ World
```

Output:

```text
Hello World
```

Quoting is often easier to read: `echo "Hello World"`.

## 8. Linux filesystem hierarchy

`/` is the root directory of the entire Linux filesystem. Everything is located below it.

| Directory | Purpose |
| --- | --- |
| `/` | Root of the filesystem |
| `/root` | Home directory of the root user |
| `/home` | Home directories of regular users |
| `/bin` | Essential user commands; commonly linked to `/usr/bin` on modern distributions |
| `/sbin` | Essential system-administration commands; commonly linked to `/usr/sbin` |
| `/etc` | System and application configuration files |
| `/dev` | Device files representing hardware and virtual devices |
| `/proc` | Virtual information about processes and the kernel |
| `/sys` | Virtual information about devices and the kernel |
| `/var` | Variable data such as logs, caches, and databases |
| `/tmp` | Temporary files |
| `/usr` | Most user-space applications, libraries, and shared data |
| `/boot` | Files needed to boot the system |
| `/lib` | Essential shared libraries; commonly linked to `/usr/lib` |
| `/opt` | Optional or third-party software |
| `/mnt` | Temporary mount point for filesystems |
| `/media` | Mount points for removable media |
| `/srv` | Data served by system services |

## 9. Searching text with `grep`

`grep` searches for a text pattern in files or command output.

```bash
grep "hello" file.txt          # Lines containing hello
grep -i "error" log.txt        # Case-insensitive search
grep -n "error" log.txt        # Include matching line numbers
grep -r "pattern" directory    # Search recursively in a directory
```

## 10. Pipes: `|`

A pipe sends the standard output of one command to the standard input of another command:

```bash
command1 | command2
```

Examples:

```bash
ps aux | grep node
ls | grep '\.txt$'
```

The first example lists processes and then displays lines containing `node`. The second lists names ending in `.txt`.
