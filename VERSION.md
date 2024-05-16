# Version log

## v4.2 - Extra Wordlists

- Added [rockyou.txt](https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt) split in two parts `rockyou_p1.txt` / `rockyou_p2.txt`
- Added [NetZwerg.txt](https://weakpass.com/wordlist/510)

## v4.1 - To Show or not to Show

- Added option `-d` / `--disable-cracked`, this will stop cracked hashes being shown, preventing flooding of the console.
- Minor fixes

## v4.0 - The Merge

- Merge of [hash-cracker-apple-silicon](https://github.com/sensepost/hash-cracker-apple-silicon) into hash-cracker

## v3.9 - Custom Brute Force

- For the heavy lifters, you can now do custom length brute force attacks
- Changed the behavior of `trap` to not only clean temporary files but keep hash-cracker alive when intentionally or unintentionally `CTRL+C` is pressed

## v3.8 - Keep it Static

- Even more ability to set static parameters
- Added link to new [blog](https://sensepost.com/blog/2023/hash-cracker-password-cracking-done-effectively/)

## v3.7 - Just Before

- Introduced `hash-cracker.conf` to set a static config yourself
- Merged `mandatory-checks.sh` and `optional-checks.sh` into `parameters.sh`
- Changed all processors to use the static config file if chosen
- Option to use the static config `--static`

## v3.6 - World Password Day

- New rule - [stacking58](https://github.com/hashcat/hashcat/blob/master/rules/stacking58.rule)
- Added Stacker based on new rule
- Hashcat hardware monitoring can be enabled from now upon

## v3.5 - New hashes

- Updated supported hash types, based on hashcat `v6.2.6-420-gdc51a1a97`

## v3.4 - No More tmp_ and More Flexibility

- Moved from `tmp_` files to proper temporary file handling
- Handling of `CTRL+C` - will remove temporary file(s)
- Renamed processors to match with menu option number
- Added `cracklib.txt`
- Added new `parameters.sh` checking script that handles parameters given by the user
- Added option to disable `--loopback` (default: Enabled)

## v3.3.1 - Small Effective Adjustments

- Changes to `digitremover.sh`

## v3.3 - 1234567890

- Added `digitremover.sh`

## v3.2 - Custom Word List Generator

- Added Polish [wordlist](https://raw.githubusercontent.com/sigo/polish-dictionary/master/dist/pl.txt)
- Added missing `--hwmon-disable` flag to `markov-generator.sh`
- Replaced OneRuleToRuleThemAll with [OneRuleToRuleThemStill](https://github.com/stealthsploit/OneRuleToRuleThemStill)
- Split `requirements.sh` into two files `mandatory` and `optional`
- Added Custom Word List Generator - [CeWL](https://github.com/digininja/CeWL/)

## v3.1 - To speed or not to speed #kernels

- Optimized kernels are used by default but can be disabled with the `-n` or `--no-limit` flag
- Help menu implemented
- Moved search functionality
- Added Markov-chain password generator based on [bujimuji/markov-passwords](https://github.com/bujimuji/markov-passwords)
- Added [Dutch OpenTaal wordlist](https://github.com/OpenTaal/opentaal-wordlist/blob/master/wordlist.txt)

## v3.0 - 🚀

Besides some small changes you can now chose if you want to run things with a single or multiple word lists. As you can imagine, this will take much longer, but it is worth it.

- Added multi word list support
- Added `german.txt` word list
- Added two new, FaceBook based rules, thanks [@singe](https://twitter.com/singe)
- Disabled hardware monitoring (`--hwmon-disable`) for all processors
- Added word list `brutas-combined` - combining all lists in the 'passwords' category from [brutas](https://github.com/tasooshi/brutas/tree/master/wordlists/passwords)

## v2.9.4 - Fixed issue

- Fixed issue with splitting usernames from source file
- Added Russian word list

## v2.9.3 - Dump Optimization

- Moved from showing cracked hashes with hashcat for use as input to directly taking the potfile
  - Performance gain +/- 15%

## v2.9.2 - Additional word lists

- Added two Afrikaans word lists
- Extended public email providers list based on:
  - [Kikobeats/free-email-domains](https://github.com/Kikobeats/free-email-domains/blob/master/domains.json)
  - [ammarshah/all_email_provider_domains.txt](https://gist.github.com/ammarshah/f5c2624d767f91a7cbdc4e54db8dd0bf)

## v2.9.1 - AWK

- Moved from `cut` to `awk` since previously it was not compatible with multiple outputs

## v2.9 - More better

- Added `keyboardwalk.txt`
- Added `email-domains`
- Added descriptive text for combinator in `showinfo.sh`
- Added `?a` to brute-force pattern
- Added multiple brute-force patterns

## v2.8 - 3-rule

- Added `3.rule`
- Updated `light.sh` and `iterate.sh` with `3.rule`
- Added COVID-19 related word list (2 parts)
- Added `Robot_MyFavorite.rule`

## v2.7 - Username as Password

- Added support for username as password (currently only NTLM tested)
  - Extended the username as password with rules

## v2.6 - No more colors

- Added working directory for easy removal after finishing project
- Added new rule
- Removed coloring

## v2.5 - Small fixes/extras

- Added extra brute force task
- Fixed issue where the variable was not cleared properly on self restart of the 'selector' scripts
- Fixed issue with hash type selector not restarting on not-known hash type
- Added `multiple-wordlists.sh` processor - option 15
- Changed starting point after finishing task to 'main' instead of 'menu'
- Added three new word lists

## v2.4 - Mask Attack

- Removed standalone usage of `rulegen.py`
- Added complete [PACK](https://github.com/iphelix/pack) (Password Analysis and Cracking Kit by Peter Kacherginsky) repo
- Added [Mask Attack](https://hashcat.net/wiki/doku.php?id=mask_attack)
- Added NTLM (-m1000) example hashes

## v2.3 - Fingerprinting

- Added [Fingerprint Attack](https://hashcat.net/wiki/doku.php?id=fingerprint_attack)
- Added [hashcat-utils](https://github.com/hashcat/hashcat-utils)

## v2.2 - Potfile

- Added specific [potfile](https://hashcat.net/wiki/doku.php?id=frequently_asked_questions#what_is_a_potfile) instead of default

## v2.1 - Extra rules for iterating

- Added 4 rules
- Extended the iterating processor

## v2.0 - Redone way of working

- Took everything from the script and put it into separate scripts
- Changed from hardcoding hashcat path to dynamically with `command -v`
- Minor rearrange of menu options
- Search function showing sorted on number instead of source file
- Removed exporting results for now - will be back in future update

## v1.7 - PACK

- Added [PACK](https://github.com/iphelix/pack) (Password Analysis and Cracking Kit by Peter Kacherginsky) `rulegen.py`
- `rulegen.py` implemented and tested for NTLM (mode 1000)
- Moved some things around

## v1.6 - Again new rules

- Introducing new rules

## v1.5 - Some new rules

- Introducing some new rules
- Small changes
- New word lists
- Added search function to easily find the right hash type mode you need
- Renamed `processor.sh` to `hash-cracker.sh`

## v1.4 - Lets enter something yourself v2

- Added function to enter a specific word as input and brute force in front and after it
- Menu rearrange

## v1.3 - Lets enter something yourself

- Added function to enter a specific word as input and randomize it
- Extended hybrid processing with non-caps jobs

## v1.2 - Optimizing

- Removed `plain processing`
- Removed plain hashes from MD5 example
- Changed `-i` to `--increment` hybrid

## v1.1 - Added rule

- Added new rule - `OptimizedUpToDate.rule`
- Small changes in list and rule lists

## v1.0 - Release fully working state

- Fully working state

## v0.9 - Light and heavy lifting

- Made light and heavy rules separate job
- Added `fordyv1.rule`

## v0.8 - Combinator

- Added combination attack support
- Reduced information directly in the menu moved to separate overview
- Added simple information about the options

## v0.7 - Loop the loop

- Added `--loopback` to rule based cracking
- Extended brute force digits from 8 to 10

## v0.6 - Added Prefix and suffix

- Implemented prefix and suffix processing
- Reordered some functions

## v0.5 - Added Toggle-Case attack

- Adjusted default `bitmap-max` size to 24
- Added two brute force defaults
- Added the following rules (leetspeak, toggles1, toggles2)
- Added new rules to default processing job
- Added basic Toggle-Case attack

## v0.4 - Added Hybrid attack

- Added hybrid attack support
- Removed line for uniq hashes output because not showing correct numbers depending on input
- Reordered start menu

## v0.3 - Added plain processing

- Added the ability to process a plain word/password list against input hashes
- Added tab completion for hash list and word list selector

## v0.2 - Multiple changes

- New improved way of performing actions
- Requirements checker
- Iterations of results put into a separate function
- Added function for result processing / output
- Results to `final.txt` removed, must now use option to show results

## v0.1 - Initial release

- Initial release
