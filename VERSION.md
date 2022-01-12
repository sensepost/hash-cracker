# Version log

## v2.4 - Mask Attack

* Removed standalone usage of `rulegen.py`
* Added complete [PACK](https://github.com/iphelix/pack) (Password Analysis and Cracking Kit by Peter Kacherginsky) repo
* Added [Mask Attack](https://hashcat.net/wiki/doku.php?id=mask_attack)
* Added NTLM (-m1000) example hashes

## v2.3 - Fingerprinting

* Added [Fingerprint Attack](https://hashcat.net/wiki/doku.php?id=fingerprint_attack)
* Added [hashcat-utils](https://github.com/hashcat/hashcat-utils)

## v2.2 - Potfile

* Added specific [potfile](https://hashcat.net/wiki/doku.php?id=frequently_asked_questions#what_is_a_potfile) instead of default

## v2.1 - Extra rules for iterating

* Added 4 rules
* Extended the iterating processor

## v2.0 - Redone way of working

* Took everything from the script and put it into separate scripts
* Changed from hardcoding hashcat path to dynamically with `command -v`
* Minor rearrange of menu options
* Search function showing sorted on number instead of source file
* Removed exporting results for now - will be back in future update

## v1.7 - PACK

* Added [PACK](https://github.com/iphelix/pack) (Password Analysis and Cracking Kit by Peter Kacherginsky) `rulegen.py`
* `rulegen.py` implemented and tested for NTLM (mode 1000)
* Moved some things around

## v1.6 - Again new rules

* Introducing new rules

## v1.5 - Some new rules

* Introducing some new rules
* Small changes
* New wordlists
* Added search function to easily find the right hashtype mode you need
* Renamed `processor.sh` to `hash-cracker.sh`

## v1.4 - Lets enter something yourself v2

* Added function to enter a specific word as input and brute force in front and after it
* Menu rearrange

## v1.3 - Lets enter something yourself

* Added function to enter a specific word as input and randomize it
* Extended hybrid processing with non-caps jobs

## v1.2 - Optimizing

* Removed `plain processing`
* Removed plain hashes from MD5 example
* Changed `-i` to `--increment` hybrid

## v1.1 - Added rule

* Added new rule - `OptimizedUpToDate.rule`
* Small changes in list and rulelists

## v1.0 - Release fully working state

* Fully working state

## v0.9 - Light and heavy lifting

* Made light and heavy rules separate job
* Added `fordyv1.rule`

## v0.8 - Combinator

* Added combination attack support
* Reduced information directly in the menu moved to separate overview
* Added simple information about the options

## v0.7 - Loop the loop

* Added `--loopback` to rule based cracking
* Extended brute force digits from 8 to 10

## v0.6 - Added Prefix and suffix

* Implemented prefix and suffix processing
* Reordered some functions

## v0.5 - Added Toggle-Case attack

* Adjusted default `bitmap-max` size to 24
* Added two bruteforce defaults
* Added the following rules (leetspeak, toggles1, toggles2)
* Added new rules to default processing job
* Added basic Toggle-Case attack

## v0.4 - Added Hybrid attack

* Added hybrid attack support
* Removed line for uniq hashes output because not showing correct numbers depending on input
* Reordered start menu

## v0.3 - Added plain processing

* Added the ability to process a plain word/password list against input hashes
* Added tab completion for hashlist and wordlist selector

## v0.2 - Multiple changes

* New improved way of performing actions
* Requirements checker
* Iterations of results put into a separate function
* Added function for result processing / output
* Results to `final.txt` removed, must now use option to show results

## v0.1 - Initial release

* Initial release
