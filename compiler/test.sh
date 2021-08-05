#!/usr/bin/bash

function Compile
{
    f1="$1.gal"
    f2="$1.fallback"
    f3="$1.raku"
    echo "Simplifying $f1 to $f2"
    rakudo ../bootstrap_compiler.raku -v -g "$f1" "$f2"
    echo "Translating $f2 to $f3"
    rakudo ../bootstrap_compiler.raku -v -r "$f2" "$f3"
}

Compile Test

echo "Running Test.raku"
rakudo Test.raku

