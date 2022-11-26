# hash-cracker

Simple script to get some hash cracking done effectively.

Some sites where you can find wordlists:

* <https://weakpass.com/>
* <https://hashmob.net/>

Want to make the ***$HEX[1234]*** Hashcat output readable? Have a look at [hex-to-readable](https://github.com/crypt0rr/hex-to-readable).

## Apple Silicon Edition

There is a separate repo with support for Apple Silicon based systems. Find it over here: [hash-cracker-apple-silicon](https://github.com/crypt0rr/hash-cracker-apple-silicon)

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

## Version log

[See here](VERSION.md)

## License

GNU GPLv3
