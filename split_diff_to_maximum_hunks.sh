#!/usr/bin/expect -f

spawn git add -p

while true { 
    expect {
        -re {Stage this hunk \[.*s.*\]\?} { send -- "s\n" }
        -re {Stage this hunk.*\?} { send -- "n\n" }
    }
}

