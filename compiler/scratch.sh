#!/usr/bin/bash

function Remove
{
    rm -f $1/*.$2
}

echo Removing Compiled Targets
Remove fallback fallback
Remove atomic atomic
Remove simple simple
Remove raku raku
Remove p6 p6
Remove pl6 pl6
Remove javascript js
Remove python py
Remove pygal/atomic atomic
Remove pygal/python py
Remove pygal/javascript js
Remove jsgal/atomic atomic
Remove jsgal/python py
Remove jsgal/javascript js
