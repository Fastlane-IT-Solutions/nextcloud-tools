# inactive_users
Get a list of users that have not logged in since time x and optionally delete or deactivate them
```
Usage: main.sh [OPTIONS]
OPTIONS includes:
                -a | --action   - Select what to do to users [display,disable,delete]   Default: display
                -d | --dir      - Define Nextcloud directory. Must be in double quotes  Default: /var/www/nextcloud
                -h | --help     - Show this help text
                -l | --limit    - Define the user limit that occ command evaluates      Default: 1000
                -o | --output   - Select output format [plain,csv,quiet]                Default: plain
                -q | --quiet    - Disable output (same as -o quiet)
                -t | --time     - Define maximum time since last login (e.g. 1 year)    Default: 1 year
                                  Valid time formats are: 
                                        X second(s)
                                        X minute(s)
                                        X hour(s)
                                        X day(s)
                                        X week(s)
                                        X month(s)
                                        X year(s)
                -u | --user     - Define the user who's executing the web server        Default: www-data
```
