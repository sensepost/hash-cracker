# hash-cracker

Simple script to get some hash cracking done effectively.

Some sites where you can find wordlists:

* <https://weakpass.com/>
* <https://hashmob.net/>

Want to make the ***$HEX[1234]*** Hashcat output readable? Have a look at [hex-to-readable](https://github.com/crypt0rr/hex-to-readable).

## Usage

```plain
$ ./hash-cracker.sh  
Hash-cracker v1.7 by crypt0rr (https://github.com/crypt0rr)

Checking if requirements are met:
[+] Hashcat is installed
[+] common-substr is executable
[+] Python2 available

0. Exit
1. Default light rules
2. Default heavy rules
3. Brute force
4. Iterate results
5. Enter specific word/name
6. Enter specific word/name (bruteforce)
7. Hybrid
8. Toggle-case
9. Combinator
10. Prefix suffix (advise: first run steps above)
11. Common substring (advise: first run steps above)
12. PACK rulegen (read option 99)
99. Show info about modules
100. Show results in usable format

Please enter number OR type 'search' to find hashtypes:
```

## Version log

[See here](https://github.com/crypt0rr/hash-cracker/blob/master/VERSION)

## License

GNU GPLv3
