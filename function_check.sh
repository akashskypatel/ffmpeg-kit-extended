
#!/bin/bash

while read -r line; do
    # check if the line is in the flutter/lib/src directory
    if grep -r -l "$line" flutter/lib/src --exclude-dir="generated"; then
        echo "$line"
    else
        echo "$line" >> missing_functions.txt
    fi
done < functions_list.txt
