#!/bin/bash
set -e
go test
ln -sf /tmp/main.js public/main.js
go build *.go && mv main /tmp/blahblahmain && /tmp/blahblahmain
