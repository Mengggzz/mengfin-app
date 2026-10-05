#!/usr/bin/env bash
cd "C:/Users/NAN/Desktop/cashflow" || exit 1

MSG="${1:-update: $(date +'%Y-%m-%d %H:%M:%S')}"

echo "========================================================"
echo "          MengFin App - Auto Commit & Push"
echo "========================================================"
echo ""

git add -A
git commit -m "$MSG"
git -c credential.helper=wincred push origin main

echo ""
echo "Selesai!"
