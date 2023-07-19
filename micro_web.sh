#!/bin/bash
echo "Hello, World" > index.html
python3 -m http.server 8080 &