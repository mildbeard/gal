#!/usr/bin/bash

function Compile
{
    f1="src/$1.gal"
    f2="fallback/$1.fallback"
    f3="raku/$1.raku"
    f4="atomic/$1.atomic"
    f5="p6/$1.p6"
    f6="python/$1.py"
    f7="javascript/$1.js"
    f8="test/$1.atomic"
    f9="test/$1.py"
    #rm -f $f2
    #echo "bootstrap $f1 to $f2"
    #rakudo ../bootstrap_compiler.raku -g "$f1" "$f2"
    #rm -f $f3
    #echo "Translating $f2 to $f3"
    #rakudo ../bootstrap_compiler.raku -r "$f2" "$f3"
    rm -f $f4
    echo "Gal Compiling $f1 to $f4"
    rakudo ../gal_compiler.raku fallback "$f1" "$f4"
    #rm -f $f4
    #echo "gal_compiler.py Compiling $f1 to $f4"
    #python3 ../gal_compiler.py fallback "$f1" "$f4"
    #rm -f $f3
    #echo "bootstrap $f4 to $f3"
    #rakudo ../bootstrap_compiler.raku -r -v "$f4" "$f3"
    #rm -f $f5
    #echo "bootstrap $f4 to $f5"
    #rakudo ../bootstrap_compiler.raku -r "$f4" "$f5"
    #rm -f $f8
    #echo "gal_compiler.raku gal '$f1' '$f8'"
    #rakudo ../gal_compiler.raku gal "$f1" "$f8"
    #cat $f8
    #rm -f $f6
    #echo "Gal Compiling $f4 to $f6"
    #rakudo ../gal_compiler.raku python "$f4" "$f6"
    rm -f $f7
    echo "Gal Compiling $f4 to $f7"
    rakudo ../gal_compiler.raku javascript "$f4" "$f7"
    #rm -f $f9
    #echo "gal_compiler.py gal '$f4' '$f9'"
    #python3 ../gal_compiler.py python "$f4" "$f9"
    #echo diff "$f6" "$f9"
    #diff "$f6" "$f9"
    #rm -f $f9
    #echo "gal_compiler.py gal '$f4' '$f9'"
    #python3 ../gal_compiler.py python "$f4" "$f9"
    #echo diff "$f6" "$f9"
    #diff "$f6" "$f9"
    #rm -f $f7
    #echo "Gal Compiling $f4 to $f7"
    #python3 ../gal_compiler.py javascript "$f4" "$f7"
}

Compile Test
#Compile Language
#Compile Debug
#Compile Main
#Compile Token
#Compile Additions
#Compile Expression
#Compile Fallback
#Compile Atomic_Expression
#Compile Element
#Compile Factory
#Compile Statement
#Compile Atomic_Statement_AM
#Compile Atomic_Statement_LZ

node javascript/Test.js

#printf "\a"
#echo Complete.
