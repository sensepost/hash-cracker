# hash-cracker

Simple script to get some hash cracking done effectively.

Some sites where you can find wordlists:

* <https://weakpass.com/>
* <https://hashmob.net/>

Want to make the ***$HEX[1234]*** Hashcat output readable? Have a look at [hex-to-readable](https://github.com/crypt0rr/hex-to-readable).

## Usage

```plain
$ ./hash-cracker.sh 
Hash-cracker v2.0 by crypt0rr (https://github.com/crypt0rr)

Checking if requirements are met:
[+] Hashcat is installed
[+] common-substr is executable
[+] Python2 available

0. Exit
1. Brute force
2. Default light rules
3. Default heavy rules
4. Enter specific word/name
5. Enter specific word/name (bruteforce)
6. Hybrid
7. Toggle-case
8. Combinator
9. Iterate results
10. Prefix suffix (advise: first run steps above)
11. Common substring (advise: first run steps above)
12. PACK rulegen (read option 99)
99. Show info about modules

Please enter number OR type 'search' to find hashtypes:
```

## Version log

[See here](VERSION.md)

## License

GNU GPLv3
