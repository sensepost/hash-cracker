# hash-cracker

Simple script to get some hash cracking done effectively.

Some sites where you can find wordlists:

* <https://weakpass.com/>
* <https://hashmob.net/>

Want to make the ***$HEX[1234]*** Hashcat output readable? Have a look at [hex-to-readable](https://github.com/crypt0rr/hex-to-readable).

## Usage

```plain
$ ./hash-cracker.sh
Hash-cracker v1.6 by crypt0rr (https://github.com/crypt0rr)

Checking if requirements are met:
[+] Hashcat is installed
[+] common-substr is executable

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
99. Show info about modules
100. Show results in usable format

Please enter number OR type 'search' to find hashtypes:
```

## Version log

### v0.1 - Initial release

* Initial release

### v0.2 - Multiple changes

* New improved way of performing actions
* Requirements checker
* Iterations of results put into a separate function
* Added function for result processing / output
* Results to `final.txt` removed, must now use option to show results

### v0.3 - Added plain processing

* Added the ability to process a plain word/password list against input hashes
* Added tab completion for hashlist and wordlist selector

### v0.4 - Added Hybrid attack

* Added hybrid attack support
* Removed line for uniq hashes output because not showing correct numbers depending on input
* Reordered start menu

### v0.5 - Added Toggle-Case attack

* Adjusted default `bitmap-max` size to 24
* Added two bruteforce defaults
* Added the following rules (leetspeak, toggles1, toggles2)
* Added new rules to default processing job
* Added basic Toggle-Case attack

### v0.6 - Added Prefix and suffix

* Implemented prefix and suffix processing
* Reordered some functions

### v0.7 - Loop the loop

* Added `--loopback` to rule based cracking
* Extended brute force digits from 8 to 10

### v0.8 - Combinator

* Added combination attack support
* Reduced information directly in the menu moved to separate overview
* Added simple information about the options

### v0.9 - Light and heavy lifting

* Made light and heavy rules separate job
* Added `fordyv1.rule`

### v1.0 - Release fully working state

* Fully working state

### v1.1 - Added rule

* Added new rule - `OptimizedUpToDate.rule`
* Small changes in list and rulelists

### v1.2 - Optimizing

* Removed `plain processing`
* Removed plain hashes from MD5 example
* Changed `-i` to `--increment` hybrid

### v1.3 - Lets enter something yourself

* Added function to enter a specific word as input and randomize it
* Extended hybrid processing with non-caps jobs

### v1.4 - Lets enter something yourself v2

* Added function to enter a specific word as input and brute force in front and after it
* Menu rearrange

### v1.5 - Some new rules

* Introducing some new rules
* Small changes
* New wordlists
* Added search function to easily find the right hashtype mode you need
* Renamed `processor.sh` to `hash-cracker.sh`

### v1.6 - Again new rules

* Introducing new rules

## License

GNU GPLv3
