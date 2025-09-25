# alert (8) -- Tool to send messages to MS Teams Workflows


## SYNOPSIS

`alert` [`-c|--config`] _configuration-file_ [`-e|--environment`] _environment_ [`-t|--title`] _"TITLE line"_ [`-b|--body`] _"body text"_ [`-f|--file`] _file-for-body-text_ [`-i|--image`] _"URL"_ [`-w|--webhook`] _"URL"_ [`-h|--help`] [`-v|--version`]

## DESCRIPTION

The `alert` command is a tool to send messages to existing MS Teams channels or work flows based on Power Automation.
The body message can be given via the command line via the `--body` argument, or via the `--file` argument or via standard input.

## CONFIGURATION

It is important to know that the package does *not* contain a configuration file! It is not an absolute requirement, but it is highly recommended to create one.
The configuration file, when not given on the command line, is stored on the default location `/etc/alert.conf` on Linux. On Windows the default location is `C:\Program Files\Common Files\Alert\alert.conf`.

The configuration file contains two variable settings:

* ENVIRONMENT=_environment_
* WEBHOOK_URL=_URL_

The `ENVIRONMENT` is optional as it can also be retrieved from the `/etc/tier` file or via the `/bin/ohai` command if present. The most common settings for `ENVIRONMENT` are:

* sandbox
* development
* qa
* uat
* production

However, it can be anything you like it to be.

The `WEBHOOK_URL` must be a valid MS Teams Work flow URL as otherwise you will get an error message like an HTTP 405 "Method Not Allowed" status code.

Example of `/etc/alert.conf`:

    ENVIRONMENT=sandbox
    WEBHOOK_URL=https://default3ac94b33913548219502eafda6592a.35.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/e2aabfb017ea4019a2a21d7cadae68c7/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=NxWZCxWioBUzDY-UPYbHmBr-VGFuhlvLN2EqDZVbr8g


## OPTIONS

    Usage: alert [[-c|--config] configuration-file] [[-e|--environment] environment] [[-t|--title] "TITLE line"] [[-b|--body] "body text"] [[-f|--file] file for body text] [[-i|--image] "URL"] [[-w|--webhook] "URL"] [[-h|--help]] [[-v|--version]]
    -e, --environment environment value (overrides config ENVIRONMENT and detection)
    -c, --config      configuration file (optional - default /etc/alert.conf)
    -t, --title       title message (required)
    -b, --body        body text (optional when --file is used)
    -f, --file        read body text from file or stdin (required when --body is not used)
    -i, --image       Logo graph URL (optional)
    -w, --webhook     webhook URL (overrides config WEBHOOK_URL)
    -h, --help        show usage (optional)
    -v, --version     show version (optional)
    
    For all options read the man page "man alert"

## EXAMPLES

Example 1: if a required paramter is missing it will generate an error:

    $ alert -e sbx -b "some text."
    Missing required --title argument.

Example 2: if `alert` found a valid configuration file (default location `/etc/alert.conf`), and has the required arguments (body and title) then we will receive a message in the MS Teams Channel corresponding with the given WEBHOOK_URL.

    $ alert -e sbx -b "some text." -t "Title"

Example 3: the body content is now coming from a file (`/etc/tier`), the title is given on the command line. The environment has been retrieved from the `/etc/tier` file, or from the output of `/bin/ohai`.

    $ alert --file /etc/tier -t "TIER"

Example 4: We use the standard input to feed the body text.

    $ cat /etc/hosts| alert  -t "HOSTS"
    Reading body from stdin...


## AUTHOR

Gratien D'haese <gdhaese1 @ its.jnj.com>

