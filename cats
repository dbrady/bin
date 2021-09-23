#!/bin/bash
# cats - cat a file, and append a newline at the end.
#
# FOR NOW: Just cat a file and append a newline always. If the file already has
# a newline, print an extra one anwyay. Then just use cat until you hit a file
# that's missing one and rerun it as cats.
cat $@
echo ""


# Detecting if a file ends is an EOF is not impossible, even in bash:
# Thank you to
# https://stackoverflow.com/questions/38746/how-to-detect-file-ends-in-newline
#
# ----------------------------------------------------------------------
# function file_ends_with_newline() {
#     [[ $(tail -c1 "$1" | wc -l) -gt 0 ]]
# }
#
# if ! file_ends_with_newline $1
# then
#     echo
#     c=`tail -c 1 $1`
#     if [ "$c" != "" ]; then
#         echo "no newline"
#     fi
# fi
# ----------------------------------------------------------------------

# But making this a fully-fledged, transparent replacement to cat, so multiple
# files can be catted with the fun options to cat like -n and such? Yeah, that's
# a bit harder. It is DOABLE (because Turing), but for my use case, which is
# "ugh, about once a month I cat a file with no newline so I have to do !! &&
# echo" (or, more likely, C-p C-e && echo <RET>) is a pain.

# So, for now, cats is just cat && echo.
