#!/usr/bin/expect -f

spawn git add -p

expect {
    -re {Stage this hunk \[.*s.*\]\?} { send -- "s\n";  exp_continue }
    -re {Stage this hunk \[.*\]\?} { send -- "n\n"; exp_continue }
    eof
}

