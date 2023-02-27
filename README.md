# hash-cracker

Simple script to get some hash cracking done effectively.

Some sites where you can find wordlists:

- <https://weakpass.com/>
- <https://hashmob.net/>

Want to make the ***$HEX[1234]*** Hashcat output readable? Have a look at [hex-to-readable](https://github.com/crypt0rr/hex-to-readable) or use [CyberChef](https://cyberchef.offsec.nl/).

## Apple Silicon Edition

There is a separate repo with support for Apple Silicon based systems. Find it over here: [hash-cracker-apple-silicon](https://github.com/crypt0rr/hash-cracker-apple-silicon)

## Installation

```plain
git clone https://github.com/crypt0rr/hash-cracker
```

### Requirements for Full Functionality

- Python2
  - `pip install pyenchant==3.0.0a1`
- [CeWL](https://github.com/digininja/CeWL/)

## Usage

```plain
./hash-cracker [FLAG]
```

## Flags

Note: flags are optional, by default hash-cracker will run with optimized kernels enabled.

```plain
    -n / --no-limit
            Disable the use of optimized kernels (limits password length)
    -m / --module-info
            Display information around modules/options
    -s [hash-name] / --search [hash-name]
            Will search local DB for hash module. E.g. '-s ntlm'
```

## Example Hashes

Example hashes are provided in 3 formats within the `example-hashes` directory.

- MD5 (`-m 0`)
- SHA1 (`-m 100`)
- NTLM (`-m 1000`)

If you feel like cracking a large database, have a look at *Have I Been Pwned (SHA1 / NTLM)* - <https://haveibeenpwned.com/Passwords>

## Version log

[See here](VERSION.md)

## License

GNU GPLv3
