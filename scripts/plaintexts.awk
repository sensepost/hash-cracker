# Line-oriented plaintext reader. Run with LC_ALL=C for byte-preserving decoding.
# Potfiles use the last colon-delimited field; wordlists use the whole record.
function fail(message) {
    print "plaintext reader: line " NR ": " message > "/dev/stderr"
    exit 1
}
function hex_digit(value) {
    return index("0123456789abcdef", tolower(value)) - 1
}
{
    word = $0
    sub(/\r$/, "", word)
    if (input_kind != "wordlist") sub(/^.*:/, "", word)
    if (word ~ /^\$HEX\[/) {
        if (word !~ /^\$HEX\[[[:xdigit:]]*\]$/) fail("malformed $HEX record")
        encoded = substr(word, 6, length(word) - 6)
        if (length(encoded) % 2) fail("odd-length $HEX record")
        word = ""
        for (position = 1; position <= length(encoded); position += 2) {
            byte = hex_digit(substr(encoded, position, 1)) * 16 + hex_digit(substr(encoded, position + 1, 1))
            if (byte == 0 || byte == 10 || byte == 13) fail("NUL, LF and CR bytes cannot be transformed as text lines")
            word = word sprintf("%c", byte)
        }
    }
    if (index(word, sprintf("%c", 0)) || index(word, "\r")) fail("NUL and CR bytes cannot be transformed as text lines")
    print word
}
