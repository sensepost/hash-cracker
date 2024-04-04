#!/bin/bash
# Author: crypt0rr - https://github.com/crypt0rr/

if [ "$1" == '-h' ] || [ "$1" == '--help' ]; then
    echo -e "Note: flags are optional, by default hash-cracker will run with optimized kernels enabled and perform loopback actions."
    echo -e "\nUsage: ./hash-cracker [FLAG]"
    echo -e "\nFlags:"
    echo -e "\t-l / --no-loopback\n\t\t Disable loopback functionality"
    echo -e "\t-n / --no-limit\n\t\t Disable the use of optimized kernels (un-limits password length)"
    echo -e "\t--hwmon-enable\n\t\t Enable hashcat to do hardware monitoring"
    echo -e "\t-m / --module-info\n\t\t Display information around modules/options"
    echo -e "\t-s [hash-name] / --search [hash-name]\n\t\t Will search local DB for hash module. E.g. '-s ntlm'"
    echo -e "\t--static\n\t\t Use the 'hash-cracker.conf' static configuration file."
    echo -e "\t-d / --disable-cracked\n\t\t Will stop output cracked hashes directly on screen."
    exit 1
elif [ "$1" == '-m' ] || [ "$1" == '--module-info' ]; then
    echo "Information about the modules"
    echo "1. Brute force: A commonly known set of brute force tasks"
    echo "2. Light rules: A wordlist + a set of non-heavy rules is ran agains the hashlist"
    echo "3. Heavy rules: A wordlist + a set of heavy rules is ran agains the hashlist (take a cup or 10 of coffee)"
    echo "4. Enter your own word, for example a company name to change around with rules"
    echo "5. Enter your own word, for example a company name to brute force before and after"
    echo "6. Hybrid: Wordlist + bruteforce random combined"
    echo "7. Toggle case: Will toggle chars randomly based on toggle rules and add couple simple rules to create variations"
    echo "8. Combinator: Will combine two input wordlists to create new passwords - first list given is the 'left' side, second list 'right' side"
    echo "9. Iterate results: Iterate gathered results from a previous performed job, advise to run this multiple times after completing other tasks"
    echo "10. Prefix suffix: Will take the already cracked hashes, take the prefix and suffix and put them together in variations"
    echo "11. Common substring: Will take the common substrings out of the already cracked hashes and create new variations"
    echo "12. PACK rulegen will take the already cracked plaintext passwords and create a new rule, the rule is then used with the wordlist of your choise. Requires pyenchant (pip3 install pyenchant==3.0.0a1) - Currently not working on Apple Silicon"
    echo "13. PACK maskgen will craft pattern-based mask attacks."
    echo "14. Fingerprint attack, disassembling cracked plaintext passwords into all its possible mutations. Using as new input and afterwards running with some rules"
    echo "15. Takes all wordlists in a folder, for example the 'wordlists'. Goes thru them plaintext and then again with OneRuleToRuleThemAll."
    echo "16. Usernames will be stripped out the NTDS dump you provide and used as input list for cracking hashes."
    echo "17. Markov-chain password generator will generate new password sets based on Time-Space Tradeoff - https://www.cs.cornell.edu/~shmat/shmat_ccs05pwd.pdf"
    echo "18. Custom Word List Generator - CeWL - Spiders a given URL and creates a custom wordlist."
    echo "19. Will take the potfile, strip the digits from the cleartexts and perform a hybrid attack accordingly, thereafter some rules to finish the job."
    echo "20. Using the stacking58.rule with a rule stacked on top of it to create even more variation on the randomness."
    echo "21. You can specify a lenght you want to brute-force, this will use the '?a' setting so the full charspace. Incremental approach is optional."
    exit 1
elif [ "$1" == '-s' ] || [ "$1" == '--search' ]; then
    TYPELIST="scripts/extensions/hashtypes"
    grep -i $2 $TYPELIST | sort
    exit 1
fi

# Dynamic Parameters
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--no-limit) KERNEL=' ' ;;
        -l|--no-loopback) LOOPBACK=' ' ;;
        --hwmon-enable) HWMON=' ';;
        --static) CONFIGFILE=' ' ;;
        -d|--disable-cracked) SHOWCRACKED=' ' ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ "$CONFIGFILE" = ' ' ]; then
    STATICCONFIG=true
else
    STATICCONFIG=false
fi

hash-cracker

if [[ "$STATICCONFIG" = true ]]; then
    source hash-cracker.conf
else
    HASHCAT=$(command -v hashcat)
    POTFILE=(hash-cracker.pot)
fi

# Logic
echo -e "\nMandatory modules:" 
if ! [ -x "$(command -v $HASHCAT)" ]; then
    echo '[-] Hashcat is not available/executable'; ((COUNTER=COUNTER + 1))
else
    echo '[+] Hashcat is executable'
fi
if test -f "$POTFILE"; then
    echo '[+] Potfile' $POTFILE 'present'
else
    echo '[-] Potfile not present, will create' $POTFILE
    touch $POTFILE
fi
if [ "$COUNTER" \> 0 ]; then
    echo -e "\nNot all mandatory requirements are met. Please fix and try again."; exit 1
fi

# Apple macOS vs Linux
UNAMEOUT="$(uname -s)"
case "${UNAMEOUT}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    *)          MACHINE="UNKNOWN:${UNAMEOUT}"
esac

if [ "$MACHINE" == "Mac" ]; then
    source scripts/mac.sh
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    source scripts/linux.sh
else
    echo "PLEASE OPEN ISSUE with output of 'uname -s'. Fallback to Linux"
    source scripts/linux.sh
fi

echo -e "\nVariable Parameters:" 
if [ "$KERNEL" = ' ' ]; then
    echo "[-] Optimised kernels disabled"
else
    echo "[+] Optimised kernels enabled"
    KERNEL='-O'
fi

if [ "$LOOPBACK" = ' ' ]; then
    echo "[-] Loopback disabled"
else
    echo "[+] Loopback enabled"
    LOOPBACK='--loopback'
fi

if [ "$HWMON" = ' ' ]; then
    echo "[+] Hardware monitoring enabled"
else
    echo "[-] Hardware monitoring disabled"
    HWMON='--hwmon-disable'
fi

if [ "$SHOWCRACKED" = ' ' ]; then
    echo "[-] STDOUT cracked hashes disabled"
    SHOWCRACKED='-o /dev/null'
else
    echo "[+] STDOUT cracked hashes enabled"
fi

if [[ "$STATICCONFIG" = true ]]; then
    echo -e "\nStatic parameters:"
    echo "[+] Potfile:" $POTFILE
    echo "[+] Hashlist:" $HASHLIST
    echo "[+] Hashtype:" $HASHTYPE
    echo "[+] Wordlist 1:" $WORDLIST
    echo "[+] Wordlist 2:" $WORDLIST2  
fi