# hash-cracker

---

Simple script to get some hash cracking done effectively. In [this blog](https://sensepost.com/blog/2023/hash-cracker-password-cracking-done-effectively/) you can read some background on hash-cracker.

---

Some sites where you can find wordlists:

- <https://weakpass.com/>
- <https://hashmob.net/>

Want to make the ***$HEX[1234]*** Hashcat output readable? Have a look at [hex-to-readable](https://github.com/crypt0rr/hex-to-readable) or use [CyberChef](https://cyberchef.offsec.nl/).

## Installation

```plain
git clone https://github.com/crypt0rr/hash-cracker
```

### Requirements for Full Functionality

#### Linux

- Python2
  - `python2 -m pip install pyenchant==3.0.0a1`
- [CeWL](https://github.com/digininja/CeWL/)

#### macOS

- [CeWL](https://github.com/digininja/CeWL/)

## Usage

```plain
./hash-cracker [FLAG]
```

## Flags

Note: flags are optional, by default hash-cracker will run with optimized kernels enabled and perform loopback actions.

```plain
        -l / --no-loopback
                 Disable loopback functionality
        -n / --no-limit
                 Disable the use of optimized kernels (un-limits password length)
        --hwmon-enable
                 Enable hashcat to do hardware monitoring
        -m / --module-info
                 Display information around modules/options
        -s [hash-name] / --search [hash-name]
                 Will search local DB for hash module. E.g. '-s ntlm'
        --static
                 Use the 'hash-cracker.conf' static configuration file.
        -d / --disable-cracked
                 Will stop output cracked hashes directly on screen.
```

## Static Configuration File

By default, hash-cracker will run in 'ask you all variable' mode. When specifying `--static` the `hash-cracker.conf` file is used for some basic settings. You can specify:

- `HASHCAT` - binary path where you've installed [hashcat](https://github.com/hashcat/hashcat)
- `HASHTYPE` - mode hashcat will run in (e.g. 1000 (NTLM))
- `HASHLIST` - file containing target hashes
- `POTFILE` - specify the potfile you want to use / create
- `WORDLIST` - specify the first static word list
- `WORDLIST2` - specify the second static word list

## Example Hashes

Example hashes are provided in 3 formats within the `example-hashes` directory.

- MD5 (`-m 0`)
- SHA1 (`-m 100`)
- NTLM (`-m 1000`)

If you feel like cracking a large database, have a look at [*Have I Been Pwned (SHA1 / NTLM)*](https://haveibeenpwned.com/Passwords)

## Version log

[See here](VERSION.md)

## License

GNU GPLv3
