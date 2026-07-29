# mismas
A hodgepodge collection of various Unix scripts

## Building the C programs

A `Makefile` is provided to compile the two C programs. Requires `gcc` and GNU make.

```bash
make          # build timeout and nanosleep
make install  # install to /usr/local/bin (override with DESTDIR)
make clean    # remove compiled binaries
```

Individual targets are also available: `make timeout`, `make nanosleep`.

---

## C programs

### nanosleep.c
A small C program that sleeps for a given number of 10ms intervals using `nanosleep(2)`.
The default value is 500 (= 0.5 seconds); accepts an integer between 1 and 999.
Generates no output on success; prints usage to stderr on error.

```
$ ./nanosleep 100   # sleep 1 second
$ ./nanosleep       # sleep 0.5 seconds (default)
```

### timeout.c
A C program based on `cratimeout.c` that runs a command with a wall-clock timeout (in seconds).
If the command does not finish in time it receives `SIGTERM`, then `SIGKILL` after 10 seconds.
The exit status mirrors the wrapped command.

```
$ ./timeout 1 sleep 3
Terminated
$ echo $?
143
$ ./timeout 1 ls
...
$ echo $?
0
$ ./timeout
Usage: ./timeout seconds cmd args
```

---

## Shell scripts

### check_write_access.sh
Walks a directory tree and produces a CSV file listing every directory alongside
the groups that hold `rwx` ACL permissions on it. Works on Linux, HP-UX and Solaris.
Pass a starting directory as the first argument, or run from the directory you want to scan.

### count_files_per_dir.sh
Prints the number of regular files in each subdirectory of a given path (defaults to `$PWD`).

```
$ ./count_files_per_dir.sh ~/bin
Start from directory /home/gdha/bin
Directory /home/gdha/bin contains 47 files
```

### fix-TLS-Logjam-vulnerability.sh
Scans `httpd.conf` files for the OpenSSL Logjam vulnerability (`+EXP` cipher suites),
backs up affected files, disables the vulnerable cipher string, and restarts the httpd
daemon. Supports HP-UX, Linux, and Solaris (Solaris restart untested).

### lan_monitoring.sh
HP-UX only. Monitors LAN and Link Aggregate status every 10 seconds during network
cable migrations or Cisco IOS upgrades. Automatically detects HP APA trunks and
Serviceguard clusters and warns about configurations that could cause a connectivity outage.

### make-zero-files.sh
Creates zero-content files across all mounted filesystems (filling free space with zeros),
then removes them. The result is much better compression when imaging a disk with `dd`.
Equivalent in purpose to the `zerofree` package. Must be run as root.

### make_rear_diskrestore_script.sh
Simulates the `rear recover` disk-layout phase and writes the resulting
`diskrestore.sh` script to disk — without actually touching any partitions.
Useful for reviewing what a recovery would do, or for attaching to a
[ReaR issue](https://github.com/rear/rear/issues) as a debugging artifact.
Handle with care; do **not** execute the generated script on a live system.

### rear2docker.sh
Runs `rear mkrescue` and imports the resulting root filesystem into a Docker image,
then drops you into an interactive container shell. Useful for inspecting or testing
a ReaR rescue environment without booting it.

### rebase_myfork_rear.sh
Rebases a personal fork of [Relax-and-Recover (ReaR)](https://github.com/rear/rear)
against the upstream `master` branch and pushes the result to your fork.
Add `alias rebase='~/bin/rebase_myfork_rear.sh'` to `.bashrc` for convenience.

### show_vm_snapshot_backups.sh
Displays VM snapshot backup history from NetBackup Data Domain, grouped by Ansible
inventory tier.

```
$ ./show_vm_snapshot_backups.sh -h
Usage: show_vm_snapshot_backups.sh [-i inventory] tier
[tier] is the ansible group name found in an inventory file of ansible
```

### test-acl-bounderies.sh
Tests the maximum number of ACL entries that can be applied to a file or directory.
Creates `N` local users and groups, applies ACLs for each, then lists the result.
The `-c` flag cleans up all created accounts and groups. Works on Linux, HP-UX and Solaris.

```
$ ./test-acl-bounderies.sh 50        # test with 50 users/groups on a file
$ ./test-acl-bounderies.sh -d 50     # also test on a directory
$ ./test-acl-bounderies.sh -c 50     # clean up previously created accounts
```

### shrc.hpux
Sets a dynamic shell prompt showing user, hostname, current directory, and a timestamp,
e.g. `[gdha@jupiter:/.root:160226.145608]`. Useful for auditing and log correlation.
Activate by adding the following to `/etc/profile`:

```sh
ENV=/etc/shrc.hpux ; export ENV
```
