# Purpose

hblock(1) is a shell script (available on homebrew) that blocks ads, beacons and malware sites. It does this by editing /etc/hosts and setting the IP address for such sites to 0.0.0.0. The issue is that hblock sometimes adds sites to /etc/hosts that are needed.

This script fixes such issues by adding good DNS hosts to the exclusion list (/etc/hblock/allow.list) and removing the corresponding entry from /etc/hosts. It will also optionally flush the DNS cache and restart the mDNSResponder daemon.

## Versions

There are two versions of the solution, a bash shell (fix-hostfiles.sh) and a C program that does the same (fix-hostfiles.c).

The shell script does all that needs doing and does so in a lightweight manner. The motivation for the C version was twofold:

* To measure the performance difference between the two solutions (i.e., a bash script vs. a binary executable), and
* To see how easy or difficult it would be for a C program to perform the same functions.

### Deprecated

Now that the C version is complete, this shell script is deprecated. It still works fine, but I won't be making an fixes or improvements this this version.

## Design Specs and man pages

There are design specs for each solution, though I never went back to update them after the coding was done, so they're inexact replicas of the actual code.

The associated man pages do a better job of explaining the final products.

## TODO

* [x] Update Bash-Design-Spec.md to remove C notes

## Hblock Allow List

 DNS names entered into /etc/hblock/allow.list are no longer "blocked"; i.e., set to IP address 0.0.0.0
