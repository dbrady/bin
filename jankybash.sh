echo 'DATELINE: Columbus, Ohio, April 2017: Ops has locked development out of all'
echo 'production and sandbox machines, locking us out of rails and database consoles.'
echo '(Memory Lane: This immeditately preceded, and almost certainly motivated, the'
echo 'introduction of the breakglass process.)'
echo
echo 'Now, the *jenkins* user has access to everything. And the CI scripts it runs'
echo 'are just glorified shell scripts. And so was born the practice of routing around'
echo "ops by using the web interface to the CI scripts as a poor man's bash prompt."
echo
echo 'I put the script block below into every CI script we used to access/dump/modify'
echo 'sandboxed data. And we called this "Jenkins Bash" monstrosity...'
echo
echo '        ▄█  ▄▀▀█▄   ▄▀▀▄ ▀▄  ▄▀▀▄ █  ▄▀▀▄ ▀▀▄  ▄▀▀█▄▄   ▄▀▀█▄   ▄▀▀▀▀▄  ▄▀▀▄ ▄▄'
echo '  ▄▀▀▀█▀ ▐ ▐ ▄▀ ▀▄ █  █ █ █ █  █ ▄▀ █   ▀▄ ▄▀ ▐ ▄▀   █ ▐ ▄▀ ▀▄ █ █   ▐ █  █   ▄▀'
echo ' █    █      █▄▄▄█ ▐  █  ▀█ ▐  █▀▄  ▐     █     █▄▄▄▀    █▄▄▄█    ▀▄   ▐  █▄▄▄█'
echo ' ▐    █     ▄▀   █   █   █    █   █       █     █   █   ▄▀   █ ▀▄   █     █   █'
echo '   ▄   ▀▄  █   ▄▀  ▄▀   █   ▄▀   █      ▄▀     ▄▀▄▄▄▀  █   ▄▀   █▀▀▀     ▄▀  ▄▀'
echo '    ▀▀▀▀   ▐   ▐   █    ▐   █    ▐      █     █    ▐   ▐   ▐    ▐       █   █'
echo '                   ▐        ▐           ▐     ▐                         ▐   ▐'
